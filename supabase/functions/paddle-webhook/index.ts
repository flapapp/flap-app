// Secure server-side handler for Paddle Billing webhooks. This is the ONLY
// place premium access is granted or revoked — the client never writes its own
// subscription state.
//
// Security: every request is authenticated by verifying the `Paddle-Signature`
// HMAC against the configured webhook secret(s) before any DB write.
// Unsigned/invalid requests are rejected with 401. Deploy without JWT
// verification (Paddle can't send a Supabase JWT); the signature IS the auth:
//
//   supabase functions deploy paddle-webhook --no-verify-jwt
//
// This one function serves BOTH Paddle environments at once. The app can be
// built against sandbox or live (--dart-define=PADDLE_ENV) and both Paddle
// environments post here; the request is matched to an environment by which
// webhook secret verifies its signature. Set the secrets you use:
//
//   supabase secrets set \
//     PADDLE_WEBHOOK_SECRET_SANDBOX=pdl_ntfset_... \
//     PADDLE_WEBHOOK_SECRET_LIVE=pdl_ntfset_...
//
// Handled events: subscription.created / .activated / .updated / .trialing /
// .canceled / .past_due, and transaction.completed / .payment_failed.
//
// transaction.completed does double duty: for a subscription transaction it
// seeds the user <-> paddle mapping, and for a one-time transaction containing
// the FL Coin price it credits coins (10 coins per $1 unit). Set the coin price
// id per environment alongside the other secrets:
//
//   supabase secrets set \
//     PADDLE_COIN_PRICE_ID_SANDBOX=pri_... \
//     PADDLE_COIN_PRICE_ID_LIVE=pri_...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

// A Paddle environment's non-shared secrets. The app can be built against
// either sandbox or live (PaddleConfig.env / --dart-define=PADDLE_ENV), and the
// matching Paddle environment posts to THIS same function URL — so we keep both
// environments' secrets side by side and pick per-request by which webhook
// secret actually verifies the signature. Set the ones you use:
//
//   PADDLE_WEBHOOK_SECRET_SANDBOX / PADDLE_WEBHOOK_SECRET_LIVE
//   PADDLE_COIN_PRICE_ID_SANDBOX  / PADDLE_COIN_PRICE_ID_LIVE
//
// The legacy single-environment secrets (PADDLE_WEBHOOK_SECRET,
// PADDLE_COIN_PRICE_ID) are still honoured as a fallback so existing
// deployments keep working.
interface PaddleEnvSecrets {
  name: string;
  webhookSecret: string;
  coinPriceId: string;
}

const LEGACY_WEBHOOK_SECRET = Deno.env.get("PADDLE_WEBHOOK_SECRET") ?? "";
const LEGACY_COIN_PRICE_ID = Deno.env.get("PADDLE_COIN_PRICE_ID") ?? "";

// FL Coins granted per $1 unit. Shared across environments; the app keeps a copy
// (PaddleConfig.coinsPerUnit) but the server value is authoritative.
const COINS_PER_UNIT = Number(Deno.env.get("PADDLE_COINS_PER_UNIT") ?? "10");

// Every configured environment, most-specific (env-suffixed) first, then the
// legacy unsuffixed secret as a catch-all for single-environment deployments.
const PADDLE_ENVS: PaddleEnvSecrets[] = [
  {
    name: "sandbox",
    webhookSecret: Deno.env.get("PADDLE_WEBHOOK_SECRET_SANDBOX") ?? "",
    coinPriceId: Deno.env.get("PADDLE_COIN_PRICE_ID_SANDBOX") ?? "",
  },
  {
    name: "production",
    webhookSecret: Deno.env.get("PADDLE_WEBHOOK_SECRET_LIVE") ?? "",
    coinPriceId: Deno.env.get("PADDLE_COIN_PRICE_ID_LIVE") ?? "",
  },
  {
    name: "legacy",
    webhookSecret: LEGACY_WEBHOOK_SECRET,
    coinPriceId: LEGACY_COIN_PRICE_ID,
  },
].filter((e) => e.webhookSecret.length > 0);

// Signature-timestamp tolerance. The HMAC IS the authentication — a valid
// signature can only come from Paddle. This window only bounds replay of a
// captured request, and duplicate deliveries are already made idempotent by the
// upsert on paddle_subscription_id. Paddle retries a failed notification for up
// to ~3 days, and a manual replay re-sends the ORIGINAL timestamp, so a tight
// window (the old 65s) rejected every legitimate retry/replay as "stale" — the
// exact bug that left paid users un-provisioned. Keep it wide.
const MAX_SIGNATURE_AGE_SECONDS = 3 * 24 * 60 * 60; // 3 days

function hexEncode(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return hexEncode(signed);
}

// Verify Paddle's `ts=...;h1=...` signature over `${ts}:${rawBody}` against each
// configured environment's webhook secret. Returns the environment whose secret
// produced a matching signature, or null if none did (unsigned / forged /
// stale). Because sandbox and live secrets differ, the one that verifies also
// tells us which Paddle environment the event came from.
async function verifySignature(
  signatureHeader: string | null,
  rawBody: string,
): Promise<PaddleEnvSecrets | null> {
  if (!signatureHeader || PADDLE_ENVS.length === 0) return null;

  const parts = Object.fromEntries(
    signatureHeader.split(";").map((kv) => {
      const [k, v] = kv.split("=");
      return [k?.trim(), v?.trim()];
    }),
  );
  const ts = parts["ts"];
  const h1 = parts["h1"];
  if (!ts || !h1) return null;

  const age = Math.abs(Math.floor(Date.now() / 1000) - Number(ts));
  if (!Number.isFinite(age) || age > MAX_SIGNATURE_AGE_SECONDS) {
    // Reject only absurdly old/malformed timestamps; retries and replays within
    // the window are accepted (idempotent upsert handles true duplicates).
    return null;
  }

  for (const paddleEnv of PADDLE_ENVS) {
    const expected = await hmacHex(paddleEnv.webhookSecret, `${ts}:${rawBody}`);
    if (timingSafeEqual(expected, h1)) return paddleEnv;
  }
  return null;
}

// Deliver an in-app + push notification to a user via the auth-independent
// system enqueue RPC. Never throws: a failed notification must not fail the
// webhook (a 500 makes Paddle retry and could re-provision), so we only log.
async function notifyUser(
  userId: string | undefined | null,
  typeCode: string,
  title: string,
  message: string,
  idempotencyKey: string,
  // deno-lint-ignore no-explicit-any
  data: Record<string, any> = {},
): Promise<void> {
  if (!userId) return;
  try {
    const { error } = await supabase.rpc("enqueue_notification_system", {
      p_target_user_id: userId,
      p_type_code: typeCode,
      p_title: title,
      p_message: message,
      p_data: { type: typeCode, ...data },
      p_action_url: "/subscription",
      p_related_table: "subscriptions",
      p_related_record_id: null,
      p_idempotency_key: idempotencyKey,
    });
    if (error) {
      console.log(`[wh] notify ${typeCode} user=${userId} failed: ${error.message}`);
    }
  } catch (e) {
    console.log(`[wh] notify ${typeCode} user=${userId} threw: ${String(e)}`);
  }
}

function formatDate(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return d.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

let cachedPremiumPlanId: string | null = null;
async function premiumPlanId(): Promise<string> {
  if (cachedPremiumPlanId) return cachedPremiumPlanId;
  const { data, error } = await supabase
    .from("subscription_plans")
    .select("id")
    .eq("code", "premium")
    .maybeSingle();
  if (error || !data) throw new Error("premium plan not found");
  cachedPremiumPlanId = data.id as string;
  return cachedPremiumPlanId;
}

function mapStatus(paddleStatus: string): string {
  switch (paddleStatus) {
    case "trialing":
      return "trial";
    case "active":
      return "active";
    case "past_due":
      return "past_due";
    case "canceled":
      return "cancelled";
    case "paused":
      return "expired";
    default:
      return "expired";
  }
}

function mapInterval(interval: string | undefined): string | null {
  if (interval === "month") return "monthly";
  if (interval === "year") return "yearly";
  return null;
}

// Resolve the app user for a Paddle event. IMPORTANT: Paddle does NOT copy a
// checkout's `custom_data` onto the subscription entity, so `subscription.*`
// events arrive with `custom_data: null`. We therefore fall back to the
// user<->paddle mapping that `transaction.completed` seeds (see
// handleTransactionEvent), matching first by subscription id then customer id.
// deno-lint-ignore no-explicit-any
async function resolveUserId(data: any): Promise<string | undefined> {
  const fromCustom = data?.custom_data?.user_id;
  if (fromCustom) return fromCustom as string;

  const subId = data?.id ?? data?.subscription_id;
  if (subId) {
    const { data: row } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("paddle_subscription_id", subId)
      .maybeSingle();
    if (row?.user_id) return row.user_id as string;
  }

  const customerId = data?.customer_id;
  if (customerId) {
    const { data: row } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("paddle_customer_id", customerId)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (row?.user_id) return row.user_id as string;
  }
  return undefined;
}

// deno-lint-ignore no-explicit-any
async function handleSubscriptionEvent(data: any): Promise<void> {
  const paddleSubId: string | undefined = data?.id;
  const userId = await resolveUserId(data);
  if (!paddleSubId || !userId) {
    console.log(
      `[wh] subscription event unmapped (dropped): sub=${paddleSubId} ` +
        `userResolved=${!!userId} custom=${JSON.stringify(data?.custom_data ?? null)}`,
    );
    return;
  }

  const status = mapStatus(String(data?.status ?? ""));
  const isActiveState = status === "trial" || status === "active";

  const priceCycle = data?.items?.[0]?.price?.billing_cycle?.interval;
  const interval = mapInterval(priceCycle);
  const periodEnd: string | null =
    data?.current_billing_period?.ends_at ?? data?.next_billed_at ?? null;
  const trialEndsAt: string | null =
    status === "trial" ? (data?.next_billed_at ?? periodEnd) : null;
  const nowIso = new Date().toISOString();

  const row: Record<string, unknown> = {
    user_id: userId,
    plan_id: await premiumPlanId(),
    status,
    paddle_subscription_id: paddleSubId,
    paddle_customer_id: data?.customer_id ?? null,
    billing_interval: interval,
    current_period_end: periodEnd,
    ends_at: periodEnd,
    trial_ends_at: trialEndsAt,
    auto_renew: !(data?.scheduled_change?.action === "cancel"),
    updated_at: nowIso,
  };

  // Keep the single-active-subscription invariant: if this event grants access,
  // expire any OTHER active/trial rows for the user first.
  if (isActiveState) {
    await supabase
      .from("subscriptions")
      .update({ status: "expired", updated_at: nowIso })
      .eq("user_id", userId)
      .in("status", ["trial", "active"])
      .neq("paddle_subscription_id", paddleSubId);
  }

  // Upsert by paddle_subscription_id (select-then-update/insert; the unique
  // index is partial so we can't use ON CONFLICT directly). The status here is
  // this subscription's PRIOR state (the single-active invariant above only
  // touched OTHER rows), so it drives transition-based notifications below.
  const { data: existing } = await supabase
    .from("subscriptions")
    .select("id, status")
    .eq("paddle_subscription_id", paddleSubId)
    .maybeSingle();

  const prevStatus = (existing?.status as string | undefined) ?? null;

  if (existing) {
    await supabase.from("subscriptions").update(row).eq("id", existing.id);
  } else {
    await supabase
      .from("subscriptions")
      .insert({ ...row, starts_at: data?.started_at ?? nowIso });
  }

  // Notify only on meaningful state transitions (Paddle sends many updates).
  const wasActive = prevStatus === "active" || prevStatus === "trial";
  if (isActiveState && !wasActive) {
    // Item 7: first grant of access (new subscription or reactivation).
    await notifyUser(
      userId,
      "premium_activated",
      "Welcome to Premium!",
      status === "trial"
        ? "Your Premium free trial is now active — enjoy full access."
        : "Your Premium subscription is now active — enjoy full access.",
      `premium_activated:${paddleSubId}`,
    );
  } else if (status === "cancelled" && prevStatus !== "cancelled") {
    // Item 11: cancelled (access usually continues until the period end).
    const until = periodEnd ? ` You'll keep access until ${formatDate(periodEnd)}.` : "";
    await notifyUser(
      userId,
      "subscription_cancelled",
      "Subscription cancelled",
      `Your Premium subscription was cancelled.${until}`,
      `subscription_cancelled:${paddleSubId}`,
    );
  } else if (status === "expired" && prevStatus !== "expired") {
    // Item 11: access has ended.
    await notifyUser(
      userId,
      "subscription_expired",
      "Premium ended",
      "Your Premium access has ended. Resubscribe anytime to regain full access.",
      `subscription_expired:${paddleSubId}`,
    );
  }
}

// How many FL Coins a completed transaction bought, derived ONLY from Paddle's
// signed payload. The quantity of the configured coin price is the source of
// truth — never `custom_data`, which the client controls and could inflate.
// deno-lint-ignore no-explicit-any
function coinsInTransaction(data: any, coinPriceId: string): number {
  if (!coinPriceId) return 0;

  // `details.line_items` is the settled view; `items` is the requested one.
  // Prefer the former and fall back so we work across payload shapes.
  const lineItems: any[] = Array.isArray(data?.details?.line_items)
    ? data.details.line_items
    : Array.isArray(data?.items)
    ? data.items
    : [];

  let units = 0;
  for (const item of lineItems) {
    const priceId = item?.price_id ?? item?.price?.id;
    if (priceId !== coinPriceId) continue;
    const qty = Number(item?.quantity ?? 0);
    if (Number.isFinite(qty) && qty > 0) units += qty;
  }
  if (units <= 0) return 0;
  return Math.floor(units * COINS_PER_UNIT);
}

// deno-lint-ignore no-explicit-any
async function handleCoinPurchase(data: any, coinPriceId: string): Promise<boolean> {
  const coins = coinsInTransaction(data, coinPriceId);
  if (coins <= 0) return false;

  const txnId: string | undefined = data?.id;
  const userId: string | undefined = data?.custom_data?.user_id;
  if (!txnId || !userId) {
    // custom_data.user_id is the only link back to the app account. Without it
    // the payment can't be attributed; log loudly so it can be granted by hand.
    console.log(
      `[wh] coin purchase txn=${txnId} coins=${coins} has no ` +
        `custom_data.user_id — cannot credit`,
    );
    return true;
  }

  const grandTotal = Number(data?.details?.totals?.grand_total ?? 0);
  const { data: credited, error } = await supabase.rpc("credit_coin_purchase", {
    p_user_id: userId,
    p_paddle_transaction_id: txnId,
    p_coins: coins,
    p_amount_cents: Number.isFinite(grandTotal) ? Math.round(grandTotal) : 0,
    p_currency: data?.currency_code ?? "USD",
    p_paddle_customer_id: data?.customer_id ?? null,
  });

  // Throw so the outer handler returns 500 and Paddle retries — a dropped
  // credit means the user paid and got nothing.
  if (error) throw new Error(`credit_coin_purchase failed: ${error.message}`);

  console.log(
    `[wh] credited ${credited} FL Coins to user=${userId} txn=${txnId}`,
  );
  return true;
}

// deno-lint-ignore no-explicit-any
async function handleTransactionEvent(
  eventType: string,
  data: any,
  coinPriceId: string,
): Promise<void> {
  const paddleSubId: string | undefined = data?.subscription_id;
  const txnId: string | undefined = data?.id;

  // One-time FL Coin purchases carry no subscription_id. Check for them before
  // the subscription-only early return below.
  if (eventType === "transaction.completed") {
    if (await handleCoinPurchase(data, coinPriceId)) return;
  }

  if (!paddleSubId) {
    // Neither a subscription nor a recognised coin purchase. Most often this
    // means the coin price id is unset or points at the wrong price for this
    // environment, which would silently swallow paid coin orders — so say so.
    console.log(
      `[wh] ${eventType} txn=${txnId} has no subscription_id and no coin ` +
        `line items (coinPriceConfigured=${!!coinPriceId}) — ignored`,
    );
    return;
  }

  const nowIso = new Date().toISOString();
  if (eventType === "transaction.payment_failed") {
    await supabase
      .from("subscriptions")
      .update({ status: "past_due", updated_at: nowIso })
      .eq("paddle_subscription_id", paddleSubId);
    // Item 10: tell the user so they can fix their payment method.
    const { data: subRow } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("paddle_subscription_id", paddleSubId)
      .maybeSingle();
    await notifyUser(
      subRow?.user_id as string | undefined,
      "payment_failed",
      "Payment failed",
      "We couldn't process your Premium payment. Update your payment method to keep your subscription.",
      `payment_failed:${txnId ?? paddleSubId}`,
    );
    return;
  }

  // transaction.completed. This is the ONLY event that reliably carries the
  // checkout's custom_data.user_id, so it's where we establish the
  // user <-> paddle_subscription/customer mapping. Later subscription.* events
  // (which lack user_id) resolve the user through this row.
  const userId: string | undefined = data?.custom_data?.user_id;
  const customerId: string | undefined = data?.customer_id;

  const { data: existing } = await supabase
    .from("subscriptions")
    .select("id, user_id, paddle_transaction_id")
    .eq("paddle_subscription_id", paddleSubId)
    .maybeSingle();

  if (existing) {
    // A completed transaction on a row that already recorded a DIFFERENT prior
    // transaction is a recurring renewal (the first payment leaves it null, so
    // the initial charge is not mistaken for a renewal). Item 9.
    const priorTxn = existing.paddle_transaction_id as string | null;
    const isRenewal = !!priorTxn && !!txnId && priorTxn !== txnId;

    await supabase
      .from("subscriptions")
      .update({
        paddle_transaction_id: txnId ?? null,
        ...(customerId ? { paddle_customer_id: customerId } : {}),
        updated_at: nowIso,
      })
      .eq("id", existing.id);

    if (isRenewal) {
      await notifyUser(
        existing.user_id as string | undefined,
        "subscription_renewed",
        "Subscription renewed",
        "Your Premium subscription renewed — thanks for staying with us!",
        `subscription_renewed:${txnId}`,
      );
    }
    return;
  }

  if (!userId) {
    console.log(
      `[wh] transaction.completed sub=${paddleSubId} has no custom_data.user_id ` +
        `and no existing row — cannot map to a user`,
    );
    return;
  }

  // No row yet (the subscription.* event was dropped because it lacked
  // user_id). Seed it: a completed transaction means the subscription is
  // paid/active; a later subscription.* event refines the status if needed.
  const interval = mapInterval(data?.items?.[0]?.price?.billing_cycle?.interval);
  const periodEnd: string | null = data?.billing_period?.ends_at ?? null;

  await supabase
    .from("subscriptions")
    .update({ status: "expired", updated_at: nowIso })
    .eq("user_id", userId)
    .in("status", ["trial", "active"]);

  await supabase.from("subscriptions").insert({
    user_id: userId,
    plan_id: await premiumPlanId(),
    status: "active",
    paddle_subscription_id: paddleSubId,
    paddle_customer_id: customerId ?? null,
    paddle_transaction_id: txnId ?? null,
    billing_interval: interval,
    current_period_end: periodEnd,
    ends_at: periodEnd,
    starts_at: nowIso,
    updated_at: nowIso,
  });
  console.log(
    `[wh] seeded premium row from transaction: user=${userId} sub=${paddleSubId}`,
  );
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const rawBody = await req.text();
  const paddleEnv = await verifySignature(
    req.headers.get("Paddle-Signature"),
    rawBody,
  );
  if (!paddleEnv) {
    return new Response(JSON.stringify({ ok: false, error: "invalid signature" }), {
      status: 401,
      headers: { "content-type": "application/json" },
    });
  }

  let event: { event_type?: string; data?: unknown };
  try {
    event = JSON.parse(rawBody);
  } catch {
    return new Response("bad json", { status: 400 });
  }

  const eventType = event.event_type ?? "";
  console.log(`[wh] received ${eventType} (env=${paddleEnv.name})`);
  try {
    if (eventType.startsWith("subscription.")) {
      await handleSubscriptionEvent(event.data);
    } else if (eventType.startsWith("transaction.")) {
      await handleTransactionEvent(eventType, event.data, paddleEnv.coinPriceId);
    }
    // Unhandled event types are acknowledged so Paddle doesn't retry them.
  } catch (e) {
    // Return 500 so Paddle retries transient DB failures.
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "content-type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
