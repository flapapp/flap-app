// Tests for the App Store helpers.
//
//   deno test --allow-env --allow-net --no-lock --node-modules-dir=false \
//     supabase/functions/_shared/appstore_test.ts
//
// The signature tests sign real ES256 JWS payloads with a THROWAWAY
// root/intermediate/leaf chain generated for this file, then point the verifier
// at that root via __setRootCertificatesForTest. That exercises the same code
// path production uses — including the Apple-specific certificate extensions
// the verifier insists on (1.2.840.113635.100.6.11.1 on the leaf,
// 1.2.840.113635.100.6.2.1 on the intermediate) — without needing a sandbox
// purchase. These keys are worthless and intentionally committed.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

// Env has to be set before the module reads it at import time.
Deno.env.set("APPLE_BUNDLE_ID", "com.flap.flapapp");
Deno.env.set("SUPABASE_URL", "http://localhost");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test");

const {
  PRODUCTS,
  __setRootCertificatesForTest,
  coinsInTransaction,
  productFor,
  verifyTransaction,
} = await import("./appstore.ts");

// --- throwaway test chain -------------------------------------------------

const ROOT_DER =
  "MIIBqzCCAVGgAwIBAgIULlujnKAFlFii403NUYU6w7FenIQwCgYIKoZIzj0EAwIwKzEVMBMGA1UEAwwMVGVzdCBSb290IENBMRIwEAYDVQQKDAlGbGFwIFRlc3QwHhcNMjYwODExMTkwOTIyWhcNMzYwODA4MTkwOTIyWjArMRUwEwYDVQQDDAxUZXN0IFJvb3QgQ0ExEjAQBgNVBAoMCUZsYXAgVGVzdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABBAKuzIoMT2fOe4vtM+LC0IWqB1M7Gf6maNvCtowKbdeHWqNSTUqgwiNKE1ZvWp8GguL5kxo1cDLi6ZlQ9ukbgmjUzBRMB0GA1UdDgQWBBRpG2n4bR9nC+w6K+DY9i1P81vPWjAfBgNVHSMEGDAWgBRpG2n4bR9nC+w6K+DY9i1P81vPWjAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIQDY1VE/5YZZYeh2RN9+DfS8Xkq2owgJgI3lITMh1J5B7QIgadzpMzPjPHUkHNM+DYQaZk2lOBlCcP14gwd77Ua/Wb4=";
const INT_DER =
  "MIIBwzCCAWigAwIBAgIUNqklwxLfuWJOdfxJwFftf7SWcc8wCgYIKoZIzj0EAwIwKzEVMBMGA1UEAwwMVGVzdCBSb290IENBMRIwEAYDVQQKDAlGbGFwIFRlc3QwHhcNMjYwODExMTkwOTIyWhcNMzYwODA4MTkwOTIyWjAwMRowGAYDVQQDDBFUZXN0IEludGVybWVkaWF0ZTESMBAGA1UECgwJRmxhcCBUZXN0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEtbGCJ2AwpkQ/OtQfq4GBs11wuFIMuaTx1nbK8bk0VWDG/zEpNeBbLgTwOV2U7AfNwF8DnAlfdAPAB1HK+OqK/KNlMGMwDwYDVR0TAQH/BAUwAwEB/zAQBgoqhkiG92NkBgIBBAIFADAdBgNVHQ4EFgQU7Sni67RqMxCEkE477Stl/mSMsO4wHwYDVR0jBBgwFoAUaRtp+G0fZwvsOivg2PYtT/Nbz1owCgYIKoZIzj0EAwIDSQAwRgIhAJuJ8r8puWybQhPrqM6DuVrFyTltH80TZJ+FleSLNpNtAiEAvXq2SLvCfAaS1uEqtJt8DcDH85vL/9hJO4HXM4cAhfo=";
const LEAF_DER =
  "MIIBvDCCAWKgAwIBAgIUAhEZKY6OC1pcE6P1qSGbEQccbGkwCgYIKoZIzj0EAwIwMDEaMBgGA1UEAwwRVGVzdCBJbnRlcm1lZGlhdGUxEjAQBgNVBAoMCUZsYXAgVGVzdDAeFw0yNjA4MTExOTA5MjJaFw0zNjA4MDgxOTA5MjJaMCgxEjAQBgNVBAMMCVRlc3QgTGVhZjESMBAGA1UECgwJRmxhcCBUZXN0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEmtc3uAJSPgqONlyDiznnVQ9I07P80S9lyfVPgPVDxz8Qt1rQAfuauxhzm3Z0l5W3gfsxYUFm9djOEf3rZjcnDaNiMGAwDAYDVR0TAQH/BAIwADAQBgoqhkiG92NkBgsBBAIFADAdBgNVHQ4EFgQUa00buBSUhgygJS0ax0AXvBar1ggwHwYDVR0jBBgwFoAU7Sni67RqMxCEkE477Stl/mSMsO4wCgYIKoZIzj0EAwIDSAAwRQIgXHb15hK27UvinJahBXTrVeXOOL3XQG7lsiEg2zzxYF0CIQC8nnwot54qGqDXCNWm35r8bAewPzOqbLYCwQ55vE9g/w==";
const LEAF_PKCS8 =
  "MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgv2xmkr7zKaCW90hNo/nWNejHuQrrUD3/Df1oL0HzVKmhRANCAASa1ze4AlI+Co42XIOLOedVD0jTs/zRL2XJ9U+A9UPHPxC3WtAB+5q7GHObdnSXlbeB+zFhQWb12M4R/etmNycN";

function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64url(bytes: Uint8Array | string): string {
  const raw = typeof bytes === "string"
    ? bytes
    : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Sign a StoreKit-shaped payload into a JWS our verifier should accept. */
async function signTransaction(payload: Record<string, unknown>): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    b64ToBytes(LEAF_PKCS8),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  // x5c order is leaf, intermediate, root — as Apple sends it.
  const header = { alg: "ES256", x5c: [LEAF_DER, INT_DER, ROOT_DER] };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  // WebCrypto emits raw r||s, which is exactly the ES256 JWS encoding.
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      { name: "ECDSA", hash: "SHA-256" },
      key,
      new TextEncoder().encode(signingInput),
    ),
  );
  return `${signingInput}.${b64url(sig)}`;
}

function transactionPayload(over: Record<string, unknown> = {}): Record<string, unknown> {
  const now = Date.now();
  return {
    bundleId: "com.flap.flapapp",
    environment: "Sandbox",
    signedDate: now,
    purchaseDate: now,
    transactionId: "2000000000000001",
    originalTransactionId: "2000000000000001",
    productId: "com.flap.flapapp.coins.100",
    quantity: 1,
    type: "Consumable",
    ...over,
  };
}

__setRootCertificatesForTest([b64ToBytes(ROOT_DER)]);

// --- product catalog ------------------------------------------------------

Deno.test("every catalog product is either coins or premium", () => {
  for (const [id, product] of Object.entries(PRODUCTS)) {
    assert(
      product.kind === "coins" || product.kind === "premium",
      `${id} has an unknown kind`,
    );
    if (product.kind === "coins") {
      assert(product.coins > 0, `${id} grants no coins`);
      // The id encodes the amount; a mismatch would silently mis-credit.
      assertEquals(
        `com.flap.flapapp.coins.${product.coins}`,
        id,
        `${id} does not match the coins it grants`,
      );
    }
  }
});

Deno.test("unknown products resolve to undefined rather than a default", () => {
  assertEquals(productFor("com.flap.flapapp.coins.999999"), undefined);
  assertEquals(productFor(undefined), undefined);
  assertEquals(productFor(""), undefined);
});

// --- coin maths -----------------------------------------------------------

Deno.test("coins scale with StoreKit quantity", () => {
  // A consumable can be bought several at a time; ignoring quantity would
  // under-credit a multi-unit purchase.
  assertEquals(coinsInTransaction({ productId: "com.flap.flapapp.coins.100", quantity: 3 }), 300);
  assertEquals(coinsInTransaction({ productId: "com.flap.flapapp.coins.10", quantity: 1 }), 10);
});

Deno.test("missing or nonsense quantity falls back to one unit", () => {
  for (const quantity of [undefined, 0, -5, Number.NaN, "abc"]) {
    assertEquals(
      coinsInTransaction({ productId: "com.flap.flapapp.coins.50", quantity }),
      50,
      `quantity=${String(quantity)}`,
    );
  }
});

Deno.test("a premium product is worth no coins", () => {
  assertEquals(coinsInTransaction({ productId: "com.flap.flapapp.premium.monthly", quantity: 1 }), 0);
  assertEquals(coinsInTransaction({ productId: "nope", quantity: 1 }), 0);
});

// --- signature verification ----------------------------------------------

Deno.test("accepts a correctly signed transaction", async () => {
  const jws = await signTransaction(transactionPayload());
  const decoded = await verifyTransaction(jws);
  assertEquals(decoded.productId, "com.flap.flapapp.coins.100");
  assertEquals(decoded.transactionId, "2000000000000001");
});

Deno.test("rejects a tampered payload", async () => {
  // Re-sign a cheap product, then swap the payload for an expensive one while
  // keeping the original signature — the classic forgery.
  const cheap = await signTransaction(
    transactionPayload({ productId: "com.flap.flapapp.coins.10" }),
  );
  const [header, _payload, signature] = cheap.split(".");
  const forgedPayload = b64url(
    JSON.stringify(transactionPayload({ productId: "com.flap.flapapp.coins.1000" })),
  );
  await assertRejects(() => verifyTransaction(`${header}.${forgedPayload}.${signature}`));
});

Deno.test("rejects a transaction for another app", async () => {
  const jws = await signTransaction(transactionPayload({ bundleId: "com.someone.else" }));
  await assertRejects(() => verifyTransaction(jws));
});

Deno.test("rejects a chain that does not reach the pinned root", async () => {
  // Point the verifier back at Apple's real root: our test chain must now fail.
  const { __setRootCertificatesForTest: reset } = await import("./appstore.ts");
  const testRoot = b64ToBytes(ROOT_DER);
  const appleRoot = b64ToBytes(
    "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==",
  );
  const jws = await signTransaction(transactionPayload());
  reset([appleRoot]);
  try {
    await assertRejects(() => verifyTransaction(jws));
  } finally {
    reset([testRoot]);
  }
});
