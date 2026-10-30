// App Store Server Notifications V2 — the authoritative source of App Store
// subscription state, the counterpart of `paddle-webhook` for iOS.
//
// `appstore-verify` fulfils a purchase the instant the app reports it, but only
// Apple can tell us what happens afterwards: renewals, expiry, billing
// failures, refunds, and the user toggling auto-renew. Without this endpoint a
// subscription would be granted once and never end.
//
// Security: every request is authenticated by verifying Apple's signature on
// the payload against the PINNED Apple root CA before any DB write (see
// _shared/appstore.ts). An unsigned or unverifiable body is rejected with 401.
// Apple cannot send a Supabase JWT, so the signature IS the auth — deploy
// without JWT verification, exactly like the Paddle webhook:
//
//   supabase functions deploy appstore-notifications --no-verify-jwt
//
// Configure the resulting URL in App Store Connect under
// App Information → App Store Server Notifications (both the production and
// sandbox URL fields). See supabase/functions/README-appstore.md.

import {
  creditCoins,
  type PremiumStatus,
  productFor,
  resolveUserId,
  upsertPremium,
  verifyNotification,
  verifyRenewalInfo,
  verifyTransaction,
} from "../_shared/appstore.ts";

/**
 * Map a notification to the subscription status it implies.
 *
 * Returning `null` means "not a subscription state change" — those
 * notifications are acknowledged and ignored rather than dropped as errors, so
 * Apple stops retrying them.
 */
function statusFor(
  notificationType: string,
  subtype: string | undefined,
): PremiumStatus | null {
  switch (notificationType) {
    case "SUBSCRIBED": // INITIAL_BUY or RESUBSCRIBE
    case "DID_RENEW":
    case "OFFER_REDEEMED":
      return "active";

    case "DID_CHANGE_RENEWAL_STATUS":
      // Turning auto-renew off does NOT end access — the user keeps it until
      // the period runs out, which is exactly what 'cancelled' means here and
      // in the Paddle webhook.
      return subtype === "AUTO_RENEW_DISABLED" ? "cancelled" : "active";

    case "DID_FAIL_TO_RENEW":
      // With a GRACE_PERIOD subtype the user still has access for now; either
      // way the billing problem is the thing to surface.
      return "past_due";

    case "EXPIRED":
    case "GRACE_PERIOD_EXPIRED":
      return "expired";

    case "REFUND":
    case "REVOKE":
      return "expired";

    default:
      return null;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  let signedPayload: string;
  try {
    const body = await req.json();
    signedPayload = String(body?.signedPayload ?? "");
  } catch {
    return new Response("invalid JSON body", { status: 400 });
  }
  if (!signedPayload) return new Response("signedPayload is required", { status: 400 });

  // deno-lint-ignore no-explicit-any
  let payload: any;
  try {
    payload = await verifyNotification(signedPayload);
  } catch (e) {
    // The signature is the authentication — a payload we cannot verify is not
    // from Apple.
    console.log(`[as-notify] unverified payload rejected: ${String(e)}`);
    return new Response("invalid signature", { status: 401 });
  }

  const notificationType: string = String(payload?.notificationType ?? "");
  const subtype: string | undefined = payload?.subtype;
  const data = payload?.data;

  try {
    // deno-lint-ignore no-explicit-any
    let txn: any = null;
    if (data?.signedTransactionInfo) {
      txn = await verifyTransaction(data.signedTransactionInfo);
    }

    if (!txn) {
      // Notifications with no transaction (e.g. TEST) are still valid traffic.
      console.log(`[as-notify] ${notificationType}/${subtype ?? "-"} with no transaction — ack`);
      return new Response("ok", { status: 200 });
    }

    const productId: string | undefined = txn?.productId;
    const originalTransactionId: string | undefined = txn?.originalTransactionId;
    const transactionId: string | undefined = txn?.transactionId;

    const userId = await resolveUserId(txn?.appAccountToken, originalTransactionId);
    if (!userId) {
      // Nothing links this purchase to an account. Log loudly so it can be
      // granted by hand, but ack — retrying will not conjure the mapping.
      console.log(
        `[as-notify] ${notificationType} txn=${transactionId} orig=${originalTransactionId} ` +
          `has no appAccountToken and no known subscription — cannot attribute`,
      );
      return new Response("ok", { status: 200 });
    }

    const product = productFor(productId);
    if (!product) {
      console.log(`[as-notify] unknown product ${productId} txn=${transactionId} — ack`);
      return new Response("ok", { status: 200 });
    }

    // Consumables (FL Coins). ONE_TIME_CHARGE is the belt-and-braces path for a
    // purchase the app never managed to report; REFUND/REVOKE on a consumable
    // is logged but not clawed back, since spent coins may already be gone.
    if (product.kind === "coins") {
      if (notificationType === "REFUND" || notificationType === "REVOKE") {
        console.log(
          `[as-notify] ${notificationType} on coin txn=${transactionId} user=${userId} — ` +
            `not clawing back automatically`,
        );
        return new Response("ok", { status: 200 });
      }
      const coins = await creditCoins(userId, txn);
      console.log(
        `[as-notify] ${notificationType} credited ${coins} coins user=${userId} txn=${transactionId}`,
      );
      return new Response("ok", { status: 200 });
    }

    // Auto-renewable subscription.
    const status = statusFor(notificationType, subtype);
    if (!status) {
      console.log(`[as-notify] ${notificationType}/${subtype ?? "-"} not a state change — ack`);
      return new Response("ok", { status: 200 });
    }

    if (!originalTransactionId) {
      console.log(`[as-notify] subscription notification without originalTransactionId — ack`);
      return new Response("ok", { status: 200 });
    }

    const expiresMs = Number(txn?.expiresDate ?? 0);
    const expiresAt = expiresMs > 0 ? new Date(expiresMs).toISOString() : null;

    // A refund/revoke ends access immediately regardless of the paid-through
    // date, so the expiry we record must not outlive the entitlement.
    const revoked = notificationType === "REFUND" || notificationType === "REVOKE" ||
      !!txn?.revocationDate;
    const effectiveExpiry = revoked ? new Date().toISOString() : expiresAt;

    // autoRenewStatus lives in the renewal info, not the transaction.
    let autoRenew = status === "active";
    if (data?.signedRenewalInfo) {
      try {
        const renewal = await verifyRenewalInfo(data.signedRenewalInfo);
        if (renewal?.autoRenewStatus !== undefined) {
          autoRenew = Number(renewal.autoRenewStatus) === 1;
        }
      } catch (e) {
        // Non-fatal: the status itself is already decided above.
        console.log(`[as-notify] renewal info unreadable: ${String(e)}`);
      }
    }

    await upsertPremium({
      userId,
      originalTransactionId,
      transactionId,
      productId,
      interval: product.interval,
      status,
      expiresAt: effectiveExpiry,
      autoRenew: revoked ? false : autoRenew,
    });

    console.log(
      `[as-notify] ${notificationType}/${subtype ?? "-"} -> ${status} ` +
        `user=${userId} orig=${originalTransactionId}`,
    );
    return new Response("ok", { status: 200 });
  } catch (e) {
    // 500 makes Apple retry — it redelivers for up to ~3 days, which is what we
    // want for a transient DB failure.
    console.log(`[as-notify] handler failed for ${notificationType}: ${String(e)}`);
    return new Response("handler error", { status: 500 });
  }
});
