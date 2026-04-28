import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

Deno.serve(async () => {
  const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
  const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
  const firebasePrivateKeyRaw = Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "";
  if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKeyRaw) {
    return new Response(
      JSON.stringify({
        ok: false,
        error:
          "FIREBASE_PROJECT_ID/FIREBASE_CLIENT_EMAIL/FIREBASE_PRIVATE_KEY are not configured",
      }),
      { status: 500 },
    );
  }
  const firebasePrivateKey = firebasePrivateKeyRaw.replace(/\\n/g, "\n");

  async function getAccessToken() {
    const header = { alg: "RS256", typ: "JWT" };
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: firebaseClientEmail,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    };
    const encoder = new TextEncoder();
    const base64url = (input: Uint8Array) =>
      btoa(String.fromCharCode(...input))
        .replace(/\+/g, "-")
        .replace(/\//g, "_")
        .replace(/=+$/g, "");
    const base64urlJson = (obj: unknown) =>
      base64url(encoder.encode(JSON.stringify(obj)));
    const unsignedToken = `${base64urlJson(header)}.${base64urlJson(payload)}`;

    const pem = firebasePrivateKey
      .replace("-----BEGIN PRIVATE KEY-----", "")
      .replace("-----END PRIVATE KEY-----", "")
      .replace(/\s+/g, "");
    const binaryDer = Uint8Array.from(
      atob(pem),
      (char) => char.charCodeAt(0),
    );
    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryDer.buffer,
      {
        name: "RSASSA-PKCS1-v1_5",
        hash: "SHA-256",
      },
      false,
      ["sign"],
    );
    const signature = new Uint8Array(
      await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        cryptoKey,
        encoder.encode(unsignedToken),
      ),
    );
    const signedJwt = `${unsignedToken}.${base64url(signature)}`;

    const response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body:
        `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${
          encodeURIComponent(signedJwt)
        }`,
    });
    if (!response.ok) {
      throw new Error(`Google OAuth token request failed: ${response.status}`);
    }
    const tokenBody = await response.json();
    const accessToken = tokenBody.access_token as string | undefined;
    if (!accessToken) {
      throw new Error("Google OAuth token response missing access_token");
    }
    return accessToken;
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken();
  } catch (error) {
    return new Response(
      JSON.stringify({ ok: false, error: String(error) }),
      { status: 500 },
    );
  }

  const { data: queueRows, error: fetchError } = await supabase
    .from("push_notification_queue")
    .select("id,user_id,title,message,related_table,related_record_id,notification_types(code)")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(100);

  if (fetchError) {
    return new Response(
      JSON.stringify({ ok: false, error: fetchError.message }),
      { status: 500 },
    );
  }

  if (!queueRows || queueRows.length === 0) {
    return new Response(JSON.stringify({ ok: true, processed: 0 }), {
      status: 200,
    });
  }

  let sent = 0;
  let failed = 0;

  for (const row of queueRows) {
    const { data: tokens, error: tokenError } = await supabase
      .from("push_tokens")
      .select("token")
      .eq("user_id", row.user_id)
      .is("revoked_at", null);
    if (tokenError) {
      failed += 1;
      await supabase.from("push_notification_queue").update({
        status: "failed",
        error_message: tokenError.message,
      }).eq("id", row.id);
      continue;
    }

    const tokenList = (tokens ?? [])
      .map((it) => it.token as string)
      .filter((token) => token.length > 0);
    if (tokenList.length === 0) {
      failed += 1;
      await supabase.from("push_notification_queue").update({
        status: "failed",
        error_message: "No active tokens for user",
      }).eq("id", row.id);
      continue;
    }

    let rowFailed = false;
    for (const token of tokenList) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
        {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: row.title,
              body: row.message,
            },
            data: {
              queue_id: row.id,
              type: row.notification_types?.code ?? "",
              ...(row.related_table === "matches"
                ? { matchId: row.related_record_id }
                : {}),
              ...(row.related_table === "challenges"
                ? { challengeId: row.related_record_id }
                : {}),
              ...(row.related_table === "videos"
                ? { videoId: row.related_record_id }
                : {}),
              ...(row.related_table === "teams"
                ? { teamId: row.related_record_id }
                : {}),
            },
            android: {
              priority: "high",
            },
            apns: {
              headers: {
                "apns-priority": "10",
              },
            },
          },
        }),
      },
      );

      if (!response.ok) {
        rowFailed = true;
      }
    }

    if (rowFailed) {
      failed += 1;
      await supabase.from("push_notification_queue").update({
        status: "failed",
        error_message: "FCM delivery failed for at least one token",
        sent_at: new Date().toISOString(),
      }).eq("id", row.id);
    } else {
      sent += 1;
      await supabase.from("push_notification_queue").update({
        status: "sent",
        error_message: null,
        sent_at: new Date().toISOString(),
      }).eq("id", row.id);
    }
  }

  return new Response(JSON.stringify({
    ok: true,
    processed: queueRows.length,
    sent,
    failed,
  }), {
    status: 200,
  });
});
