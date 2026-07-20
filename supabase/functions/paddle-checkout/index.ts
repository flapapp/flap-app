// Serves a minimal HTML page that loads Paddle.js and opens Paddle Checkout for
// the premium plan. The Flutter app loads this page inside an in-app webview and
// intercepts the `flap://checkout/*` redirects this page performs to learn the
// outcome (success / cancelled / failed).
//
// This endpoint returns only public HTML (the Paddle client-side token is not
// secret). Deploy it WITHOUT JWT verification so the webview can load it as a
// top-level navigation:
//
//   supabase functions deploy paddle-checkout --no-verify-jwt
//
// The authoritative subscription state is set by `paddle-webhook`, never here.

function escapeJs(value: string): string {
  return value
    .replace(/\\/g, "\\\\")
    .replace(/'/g, "\\'")
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/\r?\n/g, "");
}

Deno.serve((req) => {
  const url = new URL(req.url);
  const q = url.searchParams;

  const priceId = q.get("price_id") ?? "";
  const userId = q.get("user_id") ?? "";
  const email = q.get("email") ?? "";
  const env = q.get("env") === "production" ? "production" : "sandbox";
  // Prefer a token supplied by the app; fall back to a function secret.
  const token = q.get("token") || Deno.env.get("PADDLE_CLIENT_TOKEN") || "";
  const successUrl = q.get("success_url") ?? "flap://checkout/success";
  const cancelledUrl = q.get("cancelled_url") ?? "flap://checkout/cancelled";
  const failedUrl = q.get("failed_url") ?? "flap://checkout/failed";

  if (!priceId || !token) {
    return new Response("Missing price_id or Paddle token", { status: 400 });
  }

  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
  <title>Checkout</title>
  <style>
    html, body {
      margin: 0; padding: 0; height: 100%;
      background: #070A08; color: #EAF1EC;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .center {
      display: flex; align-items: center; justify-content: center;
      height: 100%; flex-direction: column; gap: 14px;
    }
    .spinner {
      width: 34px; height: 34px; border-radius: 50%;
      border: 3px solid rgba(255,255,255,.15); border-top-color: #66D16C;
      animation: spin 0.9s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    p { color: #828F86; font-size: 14px; }
  </style>
  <script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
</head>
<body>
  <div class="center">
    <div class="spinner"></div>
    <p>Opening secure checkout…</p>
  </div>
  <script>
    (function () {
      var settled = false;
      function go(target) {
        if (settled) return;
        settled = true;
        window.location.href = target;
      }
      try {
        if ('${env}' === 'sandbox') { Paddle.Environment.set('sandbox'); }
        Paddle.Initialize({
          token: '${escapeJs(token)}',
          eventCallback: function (event) {
            switch (event.name) {
              case 'checkout.completed':
                go('${escapeJs(successUrl)}');
                break;
              case 'checkout.closed':
                go('${escapeJs(cancelledUrl)}');
                break;
              case 'checkout.error':
                go('${escapeJs(failedUrl)}');
                break;
            }
          }
        });
        Paddle.Checkout.open({
          items: [{ priceId: '${escapeJs(priceId)}', quantity: 1 }],
          customer: ${email ? `{ email: '${escapeJs(email)}' }` : "undefined"},
          customData: { user_id: '${escapeJs(userId)}' },
          settings: { displayMode: 'overlay', theme: 'dark' }
        });
      } catch (e) {
        go('${escapeJs(failedUrl)}');
      }
    })();
  </script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8" },
  });
});
