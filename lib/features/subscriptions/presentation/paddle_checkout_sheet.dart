import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../theme/flap_tokens.dart';
import '../data/models/subscription.dart';
import '../data/paddle_checkout_html.dart';
import '../data/paddle_config.dart';

/// Outcome of the Paddle checkout flow.
enum CheckoutResult { success, cancelled, failed }

/// Full-screen in-app browser that loads the hosted Paddle.js checkout page and
/// resolves to a [CheckoutResult] by intercepting the `flap://checkout/*`
/// redirects the page navigates to.
class PaddleCheckoutSheet extends StatefulWidget {
  const PaddleCheckoutSheet({
    super.key,
    required this.priceId,
    this.quantity = 1,
    this.configured = true,
  });

  /// Paddle price to check out.
  final String priceId;

  /// Units of [priceId] to buy. Used by FL Coin packs (N x the $1 coin price).
  final int quantity;

  /// Whether the Paddle values this flow needs have been filled in; when false
  /// the sheet shows the "payments not configured" placeholder instead.
  final bool configured;

  /// Opens the checkout and returns the outcome (never null — a dismissed
  /// sheet resolves to [CheckoutResult.cancelled]).
  static Future<CheckoutResult> open(
    BuildContext context, {
    required String priceId,
    int quantity = 1,
    bool configured = true,
  }) async {
    final result = await Navigator.of(context).push<CheckoutResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaddleCheckoutSheet(
          priceId: priceId,
          quantity: quantity,
          configured: configured,
        ),
      ),
    );
    return result ?? CheckoutResult.cancelled;
  }

  /// Convenience entry point for the premium subscription flow.
  static Future<CheckoutResult> openSubscription(
    BuildContext context, {
    required BillingInterval interval,
  }) =>
      open(
        context,
        priceId: PaddleConfig.priceIdFor(interval),
        configured: PaddleConfig.isConfigured,
      );

  /// Convenience entry point for buying [units] x $1 worth of FL Coins.
  static Future<CheckoutResult> openCoins(
    BuildContext context, {
    required int units,
  }) =>
      open(
        context,
        priceId: PaddleConfig.priceCoins,
        quantity: units,
        configured: PaddleConfig.isCoinsConfigured,
      );

  @override
  State<PaddleCheckoutSheet> createState() => _PaddleCheckoutSheetState();
}

class _PaddleCheckoutSheetState extends State<PaddleCheckoutSheet> {
  bool _loading = true;
  bool _errored = false;
  bool _resolved = false;
  InAppWebViewController? _controller;

  void _finish(CheckoutResult result) {
    if (_resolved) return;
    _resolved = true;
    if (mounted) Navigator.of(context).pop(result);
  }

  /// Intercept the checkout page's outcome redirects.
  bool _handleRedirect(Uri? uri) {
    if (uri == null) return false;
    if (uri.scheme != 'flap') return false;
    switch (uri.host + uri.path) {
      case 'checkout/success':
        _finish(CheckoutResult.success);
        return true;
      case 'checkout/failed':
        debugPrint('[checkout] failed reason=${uri.queryParameters['reason']}');
        _finish(CheckoutResult.failed);
        return true;
      case 'checkout/cancelled':
      default:
        _finish(CheckoutResult.cancelled);
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlapColors.bg,
      appBar: AppBar(
        backgroundColor: FlapColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: FlapColors.text),
          onPressed: () => _finish(CheckoutResult.cancelled),
        ),
        title: Text(
          tr('subscription_checkout_title'),
          style: FlapText.sora(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          if (!widget.configured)
            const _ConfigMissing()
          else
            InAppWebView(
              // Load our own HTML (built client-side) rather than a hosted URL:
              // Supabase forces text/plain + a sandbox CSP on function
              // responses, which blocks Paddle.js. baseUrl gives the page a
              // real https origin for Paddle's postMessage handshake.
              initialData: InAppWebViewInitialData(
                data: buildPaddleCheckoutHtml(
                  priceId: widget.priceId,
                  quantity: widget.quantity,
                ),
                mimeType: 'text/html',
                encoding: 'utf-8',
                baseUrl: WebUri(PaddleConfig.checkoutBaseUrl),
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onConsoleMessage: (controller, msg) {
                debugPrint('[checkout webview] ${msg.message}');
              },
              shouldOverrideUrlLoading: (controller, action) async {
                final uri = action.request.url?.uriValue;
                if (_handleRedirect(uri)) {
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (_, __) {
                if (mounted) setState(() => _loading = true);
              },
              onLoadStop: (_, __) {
                if (mounted) setState(() => _loading = false);
              },
              onReceivedError: (_, __, ___) {
                if (mounted) {
                  setState(() {
                    _loading = false;
                    _errored = true;
                  });
                }
              },
            ),
          if (_loading && widget.configured)
            const Center(
              child: CircularProgressIndicator(color: FlapColors.green),
            ),
          if (_errored)
            _LoadError(onRetry: () {
              setState(() {
                _errored = false;
                _loading = true;
              });
              _controller?.reload();
            }),
        ],
      ),
    );
  }
}

class _ConfigMissing extends StatelessWidget {
  const _ConfigMissing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_suggest_rounded,
                color: FlapColors.muted, size: 40),
            const SizedBox(height: 14),
            Text(
              tr('subscription_checkout_unconfigured'),
              textAlign: TextAlign.center,
              style: FlapText.sora(
                  fontSize: 14, color: FlapColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FlapColors.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: FlapColors.red, size: 40),
            const SizedBox(height: 14),
            Text(
              tr('subscription_checkout_error'),
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 14, color: FlapColors.muted),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                tr('subscription_checkout_retry'),
                style: FlapText.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FlapColors.greenBright),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
