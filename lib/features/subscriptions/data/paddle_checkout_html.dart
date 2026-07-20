import 'package:flap_app/core/auth/app_auth.dart';

import 'paddle_config.dart';

/// Escapes a value for safe interpolation inside a single-quoted JS string.
String _escapeJs(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll("'", "\\'")
    .replaceAll('<', '\\u003c')
    .replaceAll('>', '\\u003e')
    .replaceAll('\n', '')
    .replaceAll('\r', '');

/// Builds the self-contained Paddle.js checkout page loaded into the in-app
/// webview via `initialData`.
///
/// We build this on the client instead of serving it from a Supabase edge
/// function because Supabase forces `content-type: text/plain` and a
/// `default-src 'none'; sandbox` CSP on function responses — that renders the
/// HTML as source and blocks Paddle.js. Loading it as `initialData` sidesteps
/// both: the page is ours, carries no restrictive CSP, and Paddle.js loads from
/// its own CDN. The client token and price IDs are non-secret.
///
/// [quantity] buys several units of the same price — that's how FL Coin packs
/// work (N x the $1 coin price). What the user is actually charged, and what
/// the webhook credits, is derived server-side from Paddle's own payload.
String buildPaddleCheckoutHtml({
  required String priceId,
  int quantity = 1,
}) {
  final token = _escapeJs(PaddleConfig.clientToken);
  final escapedPriceId = _escapeJs(priceId);
  final qty = quantity < 1 ? 1 : quantity;
  final userId = _escapeJs(AppAuth.currentUserId ?? '');
  final email = _escapeJs(AppAuth.currentUserEmail ?? '');
  final env = _escapeJs(PaddleConfig.env);
  final success = _escapeJs(PaddleConfig.successUrl);
  final cancelled = _escapeJs(PaddleConfig.cancelledUrl);
  final failed = _escapeJs(PaddleConfig.failedUrl);
  final isSandbox = PaddleConfig.isSandbox;

  final customer = email.isNotEmpty ? "{ email: '$email' }" : 'undefined';

  return '''<!doctype html>
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
    .center { display: flex; align-items: center; justify-content: center; height: 100%; flex-direction: column; gap: 14px; }
    .spinner { width: 34px; height: 34px; border-radius: 50%; border: 3px solid rgba(255,255,255,.15); border-top-color: #66D16C; animation: spin 0.9s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    p { color: #828F86; font-size: 14px; }
  </style>
  <script src="https://cdn.paddle.com/paddle/v2/paddle.js"></script>
</head>
<body>
  <div class="center">
    <div class="spinner"></div>
    <p>Opening secure checkout...</p>
  </div>
  <script>
    (function () {
      var settled = false;
      function go(target) { if (settled) return; settled = true; window.location.href = target; }
      function dump(o){ try { return JSON.stringify(o, function(k,v){ return v===undefined?'<undef>':v; }); } catch(e){ try { return 'keys:'+Object.keys(o).join(','); } catch(e2){ return String(o); } } }
      window.onerror = function (m, s, l, c) { console.error('[paddle] onerror: ' + m + ' @' + l + ':' + c); };
      try {
        console.error('[paddle] cfg env=$env tokenLen=' + '$token'.length + ' priceId=$escapedPriceId qty=$qty origin=' + location.origin);
        if (${isSandbox ? 'true' : 'false'}) { Paddle.Environment.set('sandbox'); }
        Paddle.Initialize({
          token: '$token',
          eventCallback: function (event) {
            console.error('[paddle] event name=' + (event && event.name) + ' full=' + dump(event));
            switch (event && event.name) {
              case 'checkout.completed': go('$success'); break;
              case 'checkout.closed': go('$cancelled'); break;
              case 'checkout.error':
                var reason = dump((event && (event.error || event.data)) || {});
                go('$failed?reason=' + encodeURIComponent(reason));
                break;
            }
          }
        });
        console.error('[paddle] initialized, version=' + (window.Paddle && Paddle.version));
        Paddle.Checkout.open({
          items: [{ priceId: '$escapedPriceId', quantity: $qty }],
          customer: $customer,
          customData: { user_id: '$userId' },
          settings: { displayMode: 'overlay', theme: 'dark' }
        });
        console.error('[paddle] checkout.open called');
      } catch (e) { console.error('[paddle] throw: ' + (e && (e.message||e)) ); go('$failed?reason=' + encodeURIComponent('throw:' + (e && (e.message||e)))); }
    })();
  </script>
</body>
</html>''';
}
