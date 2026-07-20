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

  /// Paddle price ID for the one-time FL Coin unit: a $1 USD one-time price.
  /// Checkout buys several at once through `quantity`, so this single price
  /// covers every coin pack. The webhook must have the SAME id configured as
  /// `PADDLE_COIN_PRICE_ID` or purchases will not be credited.
  static const String priceCoins = 'pri_01ky0343zcz77yeppx1xn1tke3';

  /// FL Coins granted per $1 unit purchased. Must match the webhook's
  /// `PADDLE_COINS_PER_UNIT`; the server value is authoritative.
  static const int coinsPerUnit = 10;

  /// Largest number of $1 units a single checkout may buy. Paddle enforces a
  /// per-line-item maximum quantity (100 by default); keep this at or below the
  /// value configured on the coin price or checkout will reject the order.
  static const int maxCoinUnits = 100;

  /// Bounds and step for the coin quantity selector, all derived from the rate
  /// so coins always stay a whole number of $1 units.
  static const int minCoins = coinsPerUnit; // one $1 unit
  static const int maxCoins = maxCoinUnits * coinsPerUnit;
  static const int coinStep = coinsPerUnit;

  static bool get isSandbox => env == 'sandbox';

  /// True once the placeholders have been replaced with real values.
  static bool get isConfigured =>
      !clientToken.startsWith('__') &&
      !priceMonthly.startsWith('__') &&
      !priceYearly.startsWith('__');

  /// Coin purchases need the client token plus the one-time coin price.
  static bool get isCoinsConfigured =>
      !clientToken.startsWith('__') && !priceCoins.startsWith('__');

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

