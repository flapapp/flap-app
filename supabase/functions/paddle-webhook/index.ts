// Secure server-side handler for Paddle Billing webhooks. This is the ONLY
// place premium access is granted or revoked — the client never writes its own
// subscription state.
//
// Security: every request is authenticated by verifying the `Paddle-Signature`
// HMAC against PADDLE_WEBHOOK_SECRET before any DB write. Unsigned/invalid
// requests are rejected with 401. Deploy without JWT verification (Paddle can't
// send a Supabase JWT); the signature IS the auth:
//
//   supabase functions deploy paddle-webhook --no-verify-jwt
//   supabase secrets set PADDLE_WEBHOOK_SECRET=pdl_ntfset_... PADDLE_ENV=sandbox
//
// Handled events: subscription.created / .activated / .updated / .trialing /
// .canceled / .past_due, and transaction.completed / .payment_failed.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

const WEBHOOK_SECRET = Deno.env.get("PADDLE_WEBHOOK_SECRET") ?? "";

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

// Verify Paddle's `ts=...;h1=...` signature over `${ts}:${rawBody}`.
async function verifySignature(
  signatureHeader: string | null,
  rawBody: string,
): Promise<boolean> {
  if (!signatureHeader || !WEBHOOK_SECRET) return false;

  const parts = Object.fromEntries(
    signatureHeader.split(";").map((kv) => {
      const [k, v] = kv.split("=");
      return [k?.trim(), v?.trim()];
    }),
  );
  const ts = parts["ts"];
  const h1 = parts["h1"];
  if (!ts || !h1) return false;

  const age = Math.abs(Math.floor(Date.now() / 1000) - Number(ts));
  if (!Number.isFinite(age) || age > MAX_SIGNATURE_AGE_SECONDS) {
    // Reject only absurdly old/malformed timestamps; retries and replays within
    // the window are accepted (idempotent upsert handles true duplicates).
    return false;
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signed = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${ts}:${rawBody}`),
  );
  return timingSafeEqual(hexEncode(signed), h1);
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
  // index is partial so we can't use ON CONFLICT directly).
  const { data: existing } = await supabase
    .from("subscriptions")
    .select("id")
    .eq("paddle_subscription_id", paddleSubId)
    .maybeSingle();

  if (existing) {
    await supabase.from("subscriptions").update(row).eq("id", existing.id);
  } else {
    await supabase
      .from("subscriptions")
      .insert({ ...row, starts_at: data?.started_at ?? nowIso });
  }
}

// deno-lint-ignore no-explicit-any
async function handleTransactionEvent(
  eventType: string,
  data: any,
): Promise<void> {
  const paddleSubId: string | undefined = data?.subscription_id;
  const txnId: string | undefined = data?.id;
  if (!paddleSubId) return;

  const nowIso = new Date().toISOString();
  if (eventType === "transaction.payment_failed") {
    await supabase
      .from("subscriptions")
      .update({ status: "past_due", updated_at: nowIso })
      .eq("paddle_subscription_id", paddleSubId);
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
    .select("id")
    .eq("paddle_subscription_id", paddleSubId)
    .maybeSingle();

  if (existing) {
    await supabase
      .from("subscriptions")
      .update({
        paddle_transaction_id: txnId ?? null,
        ...(customerId ? { paddle_customer_id: customerId } : {}),
        updated_at: nowIso,
      })
      .eq("id", existing.id);
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
  const valid = await verifySignature(
    req.headers.get("Paddle-Signature"),
    rawBody,
  );
  if (!valid) {
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
  console.log(`[wh] received ${eventType}`);
  try {
    if (eventType.startsWith("subscription.")) {
      await handleSubscriptionEvent(event.data);
    } else if (eventType.startsWith("transaction.")) {
      await handleTransactionEvent(eventType, event.data);
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
