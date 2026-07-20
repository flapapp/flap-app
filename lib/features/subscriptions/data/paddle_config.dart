import 'models/subscription.dart';

/// Non-secret Paddle credentials for a single environment.
///
/// Everything here ships inside the app binary or appears in checkout URLs, so
/// it is safe to commit. The Paddle API key and webhook signing secret are
/// SECRET and live only in Supabase function secrets — never here. See
/// `supabase/functions/paddle-webhook/README.md`.
class PaddleEnvCredentials {
  const PaddleEnvCredentials({
    required this.name,
    required this.clientToken,
    required this.priceMonthly,
    required this.priceYearly,
    required this.priceCoins,
  });

  /// Paddle environment name, either `'sandbox'` or `'production'`. This is the
  /// value passed to `Paddle.Environment.set()` in the checkout page.
  final String name;

  /// Paddle "client-side token" (Developer Tools → Authentication). Sandbox
  /// tokens are prefixed `test_`, live tokens `live_`.
  final String clientToken;

  /// Paddle price IDs for the premium plan (Catalog → Prices). Both prices
  /// should have the 21-day free trial configured on them in Paddle.
  final String priceMonthly;
  final String priceYearly;

  /// Paddle price ID for the one-time FL Coin unit: a $1 USD one-time price.
  /// Checkout buys several at once through `quantity`, so this single price
  /// covers every coin pack. The webhook must have the SAME id configured for
  /// this environment or purchases will not be credited.
  final String priceCoins;

  bool get isSandbox => name == 'sandbox';
}

/// Central Paddle configuration.
///
/// Holds a full set of non-secret credentials for BOTH the sandbox
/// (development) and production (live) environments. Which one is active is
/// decided at build time by the `PADDLE_ENV` dart-define — no code edits needed
/// to switch:
///
/// ```sh
/// flutter run                                   # sandbox (default)
/// flutter run   --dart-define=PADDLE_ENV=production
/// flutter build --dart-define=PADDLE_ENV=production
/// ```
///
/// Any value other than `production` resolves to sandbox, so accidental typos
/// fail safe onto the test environment. Fill the `__…__` placeholders in
/// [_production] with values from your LIVE Paddle dashboard before shipping a
/// production build.
abstract final class PaddleConfig {
  /// Active environment, selected at build time. Defaults to `sandbox`.
  static const String env = String.fromEnvironment(
    'PADDLE_ENV',
    defaultValue: 'sandbox',
  );

  /// Sandbox (development) credentials — the Paddle sandbox dashboard.
  static const PaddleEnvCredentials _sandbox = PaddleEnvCredentials(
    name: 'sandbox',
    clientToken: 'test_332113cd3bd3b17c610c9f4c0a0',
    priceMonthly: 'pri_01kxrxjaayrrpwkr3nw6bw0cjr',
    priceYearly: 'pri_01kxrxk5gh8w4xzkhbwjjnh1e6',
    priceCoins: 'pri_01ky0343zcz77yeppx1xn1tke3',
  );

  /// Production (live) credentials — the Paddle live dashboard. Replace the
  /// placeholders with the LIVE client token and price IDs before shipping.
  static const PaddleEnvCredentials _production = PaddleEnvCredentials(
    name: 'production',
    clientToken: 'live_30eede1b730eac3073dde41fb35',
    priceMonthly: 'pri_01ky0h3tgfrw7tbpa74gzxnjgn',
    priceYearly: 'pri_01ky0h5sgmcf17karhdan0654w',
    priceCoins: 'pri_01ky0h8qr9pq50xqt4fc0aey05',
  );

  /// The credential set for the active [env]. Anything that is not exactly
  /// `production` resolves to sandbox so misconfiguration fails safe.
  static PaddleEnvCredentials get active =>
      env == 'production' ? _production : _sandbox;

  static bool get isSandbox => active.isSandbox;

  /// Paddle "client-side token" for the active environment.
  static String get clientToken => active.clientToken;

  /// Premium plan price IDs for the active environment.
  static String get priceMonthly => active.priceMonthly;
  static String get priceYearly => active.priceYearly;

  /// One-time FL Coin unit price for the active environment.
  static String get priceCoins => active.priceCoins;

  /// FL Coins granted per $1 unit purchased. Must match the webhook's
  /// `PADDLE_COINS_PER_UNIT`; the server value is authoritative. This is the
  /// same across environments.
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

  /// True once the active environment's placeholders have been replaced with
  /// real values.
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
  /// checkout HTML. Paddle validates the page origin against its "approved
  /// domains" list before opening checkout, so this MUST be a domain you've
  /// added and VERIFIED there (in BOTH the sandbox and live dashboards).
  /// Nothing is fetched from it — the HTML is loaded in-memory as `initialData`,
  /// so this never renders the flapp.fun landing page; it only sets the origin
  /// string Paddle checks.
  /// (The `paddle-checkout` edge function is no longer used to render the page —
  /// Supabase forces text/plain + a sandbox CSP on function responses.)
  static const String checkoutBaseUrl = 'https://flapp.fun';

  /// Deep-link-style redirect targets the checkout page navigates to; the
  /// in-app webview intercepts these to detect the outcome.
  static const String successUrl = 'flap://checkout/success';
  static const String cancelledUrl = 'flap://checkout/cancelled';
  static const String failedUrl = 'flap://checkout/failed';
}
