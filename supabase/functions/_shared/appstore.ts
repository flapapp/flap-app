// Shared Apple App Store (StoreKit 2) helpers for the `appstore-verify` and
// `appstore-notifications` functions.
//
// iOS sells Premium and FL Coins through StoreKit because App Store guideline
// 3.1.1 requires in-app purchase for digital content. Android and web keep
// using Paddle, so both stores write the same `subscriptions` / `coin_purchases`
// rows and the rest of the app stays store-agnostic.
//
// SECURITY MODEL — identical in spirit to `paddle-webhook`:
//   * Nothing here trusts the client for *what was bought* or *how much*. The
//     only accepted input is a JWS that Apple signed; the product id inside it
//     is what decides the entitlement, and the coin amount is looked up from
//     PRODUCTS server-side.
//   * The trust root is PINNED below. We do not trust the certificate chain a
//     payload ships with — that chain is only accepted if it terminates at
//     Apple's actual root CA.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@1.6.0";

export const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

// Apple Root CA - G3, the trust anchor for every StoreKit signed payload.
// DER, base64. Verified out of band against the copy Apple publishes at
// https://www.apple.com/certificateauthority/AppleRootCA-G3.cer :
//   subject = issuer = CN=Apple Root CA - G3, O=Apple Inc., C=US   (self-signed)
//   SHA-256 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:
//           7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79
const APPLE_ROOT_CA_G3_B64 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9v" +
  "dCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UE" +
  "CgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2" +
  "WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmlj" +
  "YXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqG" +
  "SM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxE" +
  "tX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNC" +
  "MEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0P" +
  "AQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3m" +
  "eoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkL" +
  "F1vLUagM6BgD56KyKA==";

function decodeBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// Overridable ONLY so the test suite can substitute a throwaway root it
// controls. Production always uses the pinned Apple root above.
const rootCertificates: Uint8Array[] = [decodeBase64(APPLE_ROOT_CA_G3_B64)];

export const APPLE_BUNDLE_ID = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.flap.flapapp";

// Numeric App Store id (App Store Connect → App Information → Apple ID). The
// library REQUIRES it to verify production payloads; sandbox does not use it.
const APPLE_APP_APPLE_ID = Number(Deno.env.get("APPLE_APP_APPLE_ID") ?? "0");

// ---------------------------------------------------------------------------
// Product catalog
// ---------------------------------------------------------------------------

export interface CoinProduct {
  kind: "coins";
  /** Coins granted per unit purchased. Multiplied by the transaction quantity. */
  coins: number;
}

export interface PremiumProduct {
  kind: "premium";
  interval: "monthly" | "yearly";
}

export type StoreProduct = CoinProduct | PremiumProduct;

// The authoritative mapping from App Store product id to what it grants. This
// is the server-side counterpart of `AppStoreProducts` in the Flutter app; the
// app's copy is for DISPLAY ONLY. Coins are always taken from here, never from
// anything the client sends — the same rule Paddle purchases follow.
//
// Product ids must match App Store Connect exactly. See functions/README.md.
export const PRODUCTS: Record<string, StoreProduct> = {
  "com.flap.flapapp.premium.monthly": { kind: "premium", interval: "monthly" },
  "com.flap.flapapp.premium.yearly": { kind: "premium", interval: "yearly" },
  "com.flap.flapapp.coins.10": { kind: "coins", coins: 10 },
  "com.flap.flapapp.coins.50": { kind: "coins", coins: 50 },
  "com.flap.flapapp.coins.100": { kind: "coins", coins: 100 },
  "com.flap.flapapp.coins.500": { kind: "coins", coins: 500 },
  "com.flap.flapapp.coins.1000": { kind: "coins", coins: 1000 },
};

export function productFor(productId: string | undefined): StoreProduct | undefined {
  if (!productId) return undefined;
  return PRODUCTS[productId];
}

// ---------------------------------------------------------------------------
// Signature verification
// ---------------------------------------------------------------------------

// A StoreKit build talks to sandbox (Xcode / TestFlight) or production (App
// Store), and the same function URL serves both — exactly how paddle-webhook
// serves both Paddle environments at once. We therefore try each verifier in
// turn and let the signature decide, rather than trusting a client-supplied
// environment flag.
const verifierCache = new Map<Environment, SignedDataVerifier>();

function verifierFor(environment: Environment): SignedDataVerifier | undefined {
  const cached = verifierCache.get(environment);
  if (cached) return cached;
  // Production verification needs the numeric app id; without it configured we
  // simply have no production verifier (sandbox still works).
  if (environment === Environment.PRODUCTION && !APPLE_APP_APPLE_ID) return undefined;
  try {
    const verifier = new SignedDataVerifier(
      rootCertificates as unknown as Buffer[],
      // Online OCSP checks: off. They add a network round trip to Apple inside
      // every request and the pinned-root chain check is what actually
      // establishes authenticity here.
      false,
      environment,
      APPLE_BUNDLE_ID,
      environment === Environment.PRODUCTION ? APPLE_APP_APPLE_ID : undefined,
    );
    verifierCache.set(environment, verifier);
    return verifier;
  } catch (e) {
    console.log(`[as] cannot build ${environment} verifier: ${String(e)}`);
    return undefined;
  }
}

/** Environments to attempt, production first (the common case in the wild). */
const ENVIRONMENTS: Environment[] = [Environment.PRODUCTION, Environment.SANDBOX];

async function verifyAcrossEnvironments<T>(
  what: string,
  run: (verifier: SignedDataVerifier) => Promise<T>,
): Promise<T> {
  let lastError: unknown;
  let attempted = 0;
  for (const environment of ENVIRONMENTS) {
    const verifier = verifierFor(environment);
    if (!verifier) continue;
    attempted++;
    try {
      return await run(verifier);
    } catch (e) {
      lastError = e;
    }
  }
  if (attempted === 0) {
    throw new Error(`no App Store verifier configured — cannot verify ${what}`);
  }
  throw new Error(`${what} failed verification: ${String(lastError)}`);
}

// deno-lint-ignore no-explicit-any
export function verifyTransaction(signedTransaction: string): Promise<any> {
  return verifyAcrossEnvironments(
    "signed transaction",
    (v) => v.verifyAndDecodeTransaction(signedTransaction),
  );
}

// deno-lint-ignore no-explicit-any
export function verifyNotification(signedPayload: string): Promise<any> {
  return verifyAcrossEnvironments(
    "signed notification",
    (v) => v.verifyAndDecodeNotification(signedPayload),
  );
}

// deno-lint-ignore no-explicit-any
export function verifyRenewalInfo(signedRenewalInfo: string): Promise<any> {
  return verifyAcrossEnvironments(
    "signed renewal info",
    (v) => v.verifyAndDecodeRenewalInfo(signedRenewalInfo),
  );
}

/** Test seam: swap the pinned root for one the test suite generated. */
export function __setRootCertificatesForTest(certs: Uint8Array[]): void {
  rootCertificates.length = 0;
  rootCertificates.push(...certs);
  verifierCache.clear();
}

// ---------------------------------------------------------------------------
// Account linking
// ---------------------------------------------------------------------------

// StoreKit's `appAccountToken` is the counterpart of Paddle's
// `custom_data.user_id`: a UUID the app attaches at purchase time so the
// signed transaction points back at an account. Our Supabase user ids are
// already UUIDs, so the token IS the user id.
//
// It can legitimately be absent — a purchase restored on a fresh install, or
// one made before the app started setting it — so we fall back to the
// subscription row keyed by originalTransactionId, mirroring how
// paddle-webhook falls back to its user<->paddle mapping.
export async function resolveUserId(
  appAccountToken: string | undefined,
  originalTransactionId: string | undefined,
): Promise<string | undefined> {
  if (appAccountToken) return appAccountToken;
  if (originalTransactionId) {
    const { data } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("app_store_original_transaction_id", originalTransactionId)
      .maybeSingle();
    if (data?.user_id) return data.user_id as string;

    const { data: purchase } = await supabase
      .from("coin_purchases")
      .select("user_id")
      .eq("app_store_transaction_id", originalTransactionId)
      .maybeSingle();
    if (purchase?.user_id) return purchase.user_id as string;
  }
  return undefined;
}

let cachedPremiumPlanId: string | null = null;

export async function premiumPlanId(): Promise<string> {
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

// ---------------------------------------------------------------------------
// Notifications (copied in behaviour from paddle-webhook so both stores produce
// the same user-visible messages)
// ---------------------------------------------------------------------------

export async function notifyUser(
  userId: string | undefined | null,
  typeCode: string,
  title: string,
  message: string,
  idempotencyKey: string,
): Promise<void> {
  if (!userId) return;
  try {
    const { error } = await supabase.rpc("enqueue_notification_system", {
      p_target_user_id: userId,
      p_type_code: typeCode,
      p_title: title,
      p_message: message,
      p_data: { type: typeCode },
      p_action_url: "/subscription",
      p_related_table: "subscriptions",
      p_related_record_id: null,
      p_idempotency_key: idempotencyKey,
    });
    if (error) console.log(`[as] notify ${typeCode} user=${userId} failed: ${error.message}`);
  } catch (e) {
    console.log(`[as] notify ${typeCode} user=${userId} threw: ${String(e)}`);
  }
}

export function formatDate(iso: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return d.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// ---------------------------------------------------------------------------
// Fulfilment
// ---------------------------------------------------------------------------

/** Coins a signed transaction is worth: the product's rate times its quantity. */
export function coinsInTransaction(
  // deno-lint-ignore no-explicit-any
  transaction: any,
): number {
  const product = productFor(transaction?.productId);
  if (!product || product.kind !== "coins") return 0;
  // Consumables can be bought several at a time; StoreKit reports that in
  // `quantity`. Ignoring it would under-credit a multi-unit purchase.
  const quantity = Number(transaction?.quantity ?? 1);
  const units = Number.isFinite(quantity) && quantity > 0 ? Math.floor(quantity) : 1;
  return product.coins * units;
}

/**
 * Credit an FL Coin purchase. Idempotent on the App Store transaction id, so
 * replays (the client retrying, plus a later server notification for the same
 * purchase) credit exactly once.
 *
 * Returns the coins the transaction is worth, or 0 if it is not a coin product.
 */
export async function creditCoins(
  userId: string,
  // deno-lint-ignore no-explicit-any
  transaction: any,
): Promise<number> {
  const coins = coinsInTransaction(transaction);
  if (coins <= 0) return 0;

  const transactionId: string | undefined = transaction?.transactionId;
  if (!transactionId) throw new Error("coin transaction has no transactionId");

  // `price` is in thousandths of a currency unit when Apple sends it at all;
  // amount_cents is display-only bookkeeping, so a missing price is fine.
  const price = Number(transaction?.price ?? 0);
  const amountCents = Number.isFinite(price) && price > 0 ? Math.round(price / 10) : 0;

  const { data, error } = await supabase.rpc("credit_appstore_coin_purchase", {
    p_user_id: userId,
    p_app_store_transaction_id: transactionId,
    p_coins: coins,
    p_amount_cents: amountCents,
    p_currency: transaction?.currency ?? "USD",
  });
  // Throw so the caller returns 5xx and the delivery is retried — a dropped
  // credit is a paid-but-not-delivered purchase.
  if (error) throw new Error(`credit_appstore_coin_purchase failed: ${error.message}`);

  return Number(data ?? coins);
}

export type PremiumStatus = "active" | "expired" | "cancelled" | "past_due";

/**
 * Write the premium subscription row for an App Store transaction, keyed by
 * originalTransactionId (the id that survives every renewal).
 *
 * Mirrors handleSubscriptionEvent in paddle-webhook, including the
 * single-active-subscription invariant and the transition-based notifications,
 * so a user's experience is identical whichever store billed them.
 */
export async function upsertPremium(opts: {
  userId: string;
  originalTransactionId: string;
  transactionId?: string;
  productId?: string;
  interval: "monthly" | "yearly" | null;
  status: PremiumStatus;
  expiresAt: string | null;
  autoRenew: boolean;
}): Promise<void> {
  const { userId, originalTransactionId, status, expiresAt } = opts;
  const isActiveState = status === "active";
  const nowIso = new Date().toISOString();

  const row: Record<string, unknown> = {
    user_id: userId,
    plan_id: await premiumPlanId(),
    status,
    app_store_original_transaction_id: originalTransactionId,
    app_store_transaction_id: opts.transactionId ?? null,
    app_store_product_id: opts.productId ?? null,
    billing_interval: opts.interval,
    current_period_end: expiresAt,
    ends_at: expiresAt,
    auto_renew: opts.autoRenew,
    updated_at: nowIso,
  };

  // Single-active-subscription invariant: if this grants access, expire any
  // OTHER active/trial row for the user first — including a Paddle one, so a
  // user who switches platforms cannot end up with two live subscriptions.
  if (isActiveState) {
    await supabase
      .from("subscriptions")
      .update({ status: "expired", updated_at: nowIso })
      .eq("user_id", userId)
      .in("status", ["trial", "active"])
      .or(
        `app_store_original_transaction_id.is.null,` +
          `app_store_original_transaction_id.neq.${originalTransactionId}`,
      );
  }

  const { data: existing } = await supabase
    .from("subscriptions")
    .select("id, status")
    .eq("app_store_original_transaction_id", originalTransactionId)
    .maybeSingle();

  const prevStatus = existing?.status as string | undefined;

  if (existing) {
    await supabase.from("subscriptions").update(row).eq("id", existing.id);
  } else {
    await supabase.from("subscriptions").insert({ ...row, starts_at: nowIso });
  }

  // Notify only on meaningful transitions — renewals fire a notification on
  // every billing period otherwise.
  const wasActive = prevStatus === "active" || prevStatus === "trial";
  if (isActiveState && !wasActive) {
    await notifyUser(
      userId,
      "premium_activated",
      "Welcome to Premium!",
      "Your Premium subscription is now active — enjoy full access.",
      `premium_activated:${originalTransactionId}`,
    );
  } else if (status === "cancelled" && prevStatus !== "cancelled") {
    const until = expiresAt ? ` You'll keep access until ${formatDate(expiresAt)}.` : "";
    await notifyUser(
      userId,
      "subscription_cancelled",
      "Subscription cancelled",
      `Your Premium subscription was cancelled.${until}`,
      `subscription_cancelled:${originalTransactionId}`,
    );
  } else if (status === "expired" && prevStatus !== "expired") {
    await notifyUser(
      userId,
      "subscription_expired",
      "Premium ended",
      "Your Premium access has ended. Resubscribe anytime to regain full access.",
      `subscription_expired:${originalTransactionId}`,
    );
  } else if (status === "past_due" && prevStatus !== "past_due") {
    await notifyUser(
      userId,
      "payment_failed",
      "Payment failed",
      "We couldn't process your Premium payment. Update your payment method to keep your subscription.",
      `payment_failed:${originalTransactionId}`,
    );
  }
}
