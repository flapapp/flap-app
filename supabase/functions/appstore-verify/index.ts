// Fulfils an App Store (StoreKit 2) purchase the moment the app reports it.
//
// The client posts the JWS `serverVerificationData` it got from StoreKit; we
// verify Apple's signature, look up what the product grants, and credit coins
// or grant premium. This is the FAST path — `appstore-notifications` is the
// authoritative one and will (re)apply the same purchase if this never runs.
// Both are idempotent on the App Store transaction id, so they can race safely.
//
// Deploy WITH JWT verification (the default) — unlike the Paddle webhook, this
// endpoint is called by the signed-in app, so the caller's identity matters:
//
//   supabase functions deploy appstore-verify
//
// Required secrets: APPLE_BUNDLE_ID, and APPLE_APP_APPLE_ID for production
// payloads. See supabase/functions/README-appstore.md.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  creditCoins,
  productFor,
  upsertPremium,
  verifyTransaction,
} from "../_shared/appstore.ts";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/** The signed-in user making this call, from the request's own JWT. */
async function callerUserId(req: Request): Promise<string | undefined> {
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader) return undefined;
  const client = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data, error } = await client.auth.getUser();
  if (error) return undefined;
  return data.user?.id;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const caller = await callerUserId(req);
  if (!caller) return json({ error: "unauthenticated" }, 401);

  let signedTransaction: string;
  try {
    const body = await req.json();
    signedTransaction = String(body?.signedTransaction ?? "");
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  if (!signedTransaction) return json({ error: "signedTransaction is required" }, 400);

  // deno-lint-ignore no-explicit-any
  let txn: any;
  try {
    txn = await verifyTransaction(signedTransaction);
  } catch (e) {
    // An unverifiable payload is not a server error — it is a bad request.
    console.log(`[as-verify] rejected: ${String(e)}`);
    return json({ error: "transaction failed verification" }, 400);
  }

  const transactionId: string | undefined = txn?.transactionId;
  const originalTransactionId: string | undefined = txn?.originalTransactionId;
  const productId: string | undefined = txn?.productId;
  const appAccountToken: string | undefined = txn?.appAccountToken;

  // Who owns this purchase. `appAccountToken` is what the buying device
  // attached, so it wins over the caller's JWT: otherwise anyone could replay
  // somebody else's signed transaction and have it credited to themselves.
  // (It is idempotent per transaction id, so the real owner would then be
  // permanently unable to claim their own purchase.)
  if (appAccountToken && appAccountToken.toLowerCase() !== caller.toLowerCase()) {
    console.log(
      `[as-verify] owner mismatch txn=${transactionId} ` +
        `token=${appAccountToken} caller=${caller}`,
    );
    return json({ error: "transaction belongs to another account" }, 403);
  }
  const userId = appAccountToken ?? caller;

  // A refunded/revoked transaction must never grant anything.
  if (txn?.revocationDate) {
    console.log(`[as-verify] revoked txn=${transactionId} — nothing granted`);
    return json({ ok: true, kind: "revoked" });
  }

  const product = productFor(productId);
  if (!product) {
    console.log(`[as-verify] unknown product ${productId} txn=${transactionId}`);
    return json({ error: `unknown product ${productId}` }, 400);
  }

  try {
    if (product.kind === "coins") {
      const coins = await creditCoins(userId, txn);
      console.log(`[as-verify] credited ${coins} coins user=${userId} txn=${transactionId}`);
      return json({ ok: true, kind: "coins", coins });
    }

    // Premium. `expiresDate` is epoch milliseconds.
    const expiresMs = Number(txn?.expiresDate ?? 0);
    const expiresAt = expiresMs > 0 ? new Date(expiresMs).toISOString() : null;
    const active = expiresMs > Date.now();

    if (!originalTransactionId) {
      return json({ error: "subscription has no originalTransactionId" }, 400);
    }

    await upsertPremium({
      userId,
      originalTransactionId,
      transactionId,
      productId,
      interval: product.interval,
      status: active ? "active" : "expired",
      expiresAt,
      // The transaction payload carries no renewal flag — only the server
      // notifications do. A fresh purchase renews by default; a later
      // DID_CHANGE_RENEWAL_STATUS notification corrects this if the user
      // turns it off.
      autoRenew: true,
    });
    console.log(
      `[as-verify] premium ${active ? "active" : "expired"} user=${userId} ` +
        `orig=${originalTransactionId}`,
    );
    return json({ ok: true, kind: "premium", active, expiresAt });
  } catch (e) {
    // 5xx so the app retries — a dropped fulfilment is a paid-but-undelivered
    // purchase. The client keeps the transaction uncompleted until we succeed.
    console.log(`[as-verify] fulfilment failed txn=${transactionId}: ${String(e)}`);
    return json({ error: "fulfilment failed" }, 500);
  }
});
