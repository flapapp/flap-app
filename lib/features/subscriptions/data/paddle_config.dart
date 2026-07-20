import '../../../core/config/supabase_env.dart';
import 'models/subscription.dart';

/// Central Paddle configuration.
///
/// Only NON-SECRET values live here (the client-side token ships inside the app
/// binary and the price IDs appear in checkout URLs). The Paddle API key and
/// webhook signing secret are SECRET and live only in Supabase function
/// secrets — never in this file or the repo. See
/// `supabase/functions/paddle-webhook/README.md`.
///
/// Fill the three `__…__` placeholders with values from your Paddle dashboard.
abstract final class PaddleConfig {
  /// 'sandbox' or 'production'. Start on sandbox; flip to 'production' when the
  /// dashboard, prices and webhook are live.
  static const String env = 'sandbox';

  /// Paddle "client-side token" (Developer Tools → Authentication).
  static const String clientToken = 'test_332113cd3bd3b17c610c9f4c0a0';

  /// Paddle price IDs for the premium plan (Catalog → Prices). Both prices
  /// should have the 21-day free trial configured on them in Paddle.
  static const String priceMonthly = 'pri_01kxrxjaayrrpwkr3nw6bw0cjr';
  static const String priceYearly = 'pri_01kxrxk5gh8w4xzkhbwjjnh1e6';

  static bool get isSandbox => env == 'sandbox';

  /// True once the placeholders have been replaced with real values.
  static bool get isConfigured =>
      !clientToken.startsWith('__') &&
      !priceMonthly.startsWith('__') &&
      !priceYearly.startsWith('__');

  static String priceIdFor(BillingInterval interval) =>
      interval == BillingInterval.yearly ? priceYearly : priceMonthly;

  /// Origin used as the webview `baseUrl` when loading the client-built
  /// checkout HTML. Paddle uses the page origin for its checkout postMessage
  /// handshake; add this domain to your Paddle "approved domains" list.
  /// (The `paddle-checkout` edge function is no longer used to render the page —
  /// Supabase forces text/plain + a sandbox CSP on function responses.)
  static String get checkoutBaseUrl => SupabaseEnv.url;

  /// Deep-link-style redirect targets the checkout page navigates to; the
  /// in-app webview intercepts these to detect the outcome.
  static const String successUrl = 'flap://checkout/success';
  static const String cancelledUrl = 'flap://checkout/cancelled';
  static const String failedUrl = 'flap://checkout/failed';
}

