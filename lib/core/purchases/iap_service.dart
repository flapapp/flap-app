import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/app_auth.dart';
import 'app_store_products.dart';

/// Outcome of a StoreKit purchase attempt.
enum PurchaseOutcome {
  /// Paid AND fulfilled server-side — coins credited / premium granted.
  success,

  /// The user dismissed the App Store sheet. Nothing was charged.
  cancelled,

  /// StoreKit reported an error, or the server refused the transaction.
  failed,

  /// Charged, but fulfilment hasn't been confirmed yet — either Apple has the
  /// purchase in "pending" (Ask to Buy / SCA), or our verification call did not
  /// get through. The purchase is NOT lost: StoreKit redelivers it and
  /// `appstore-notifications` applies it independently, so the caller must say
  /// "on its way", never "failed".
  pending,
}

/// Drives StoreKit purchases on iOS and has the server fulfil them.
///
/// The app never grants itself anything. A purchase is only worth something
/// once `appstore-verify` has checked Apple's signature on the transaction and
/// written the coins/subscription row with the service-role key — the same rule
/// the Paddle flow follows. What this class does is: start the purchase, hand
/// the signed transaction to the server, and tell StoreKit the transaction is
/// finished ONLY after the server accepted it.
class IapService {
  IapService._();

  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Completers for purchases this session started, keyed by product id.
  final Map<String, Completer<PurchaseOutcome>> _pending =
      <String, Completer<PurchaseOutcome>>{};

  /// Cached StoreKit product details (prices, localized titles), by product id.
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};

  bool _initialised = false;

  /// StoreKit is the purchase path on iOS only; everywhere else Paddle stays.
  static bool get isSupported => !kIsWeb && Platform.isIOS;

  /// Start listening for purchase updates. Safe to call more than once.
  ///
  /// This must run at app start, not just when the store UI opens: StoreKit
  /// redelivers transactions that were never finished (app killed mid-purchase,
  /// verification that failed last time), and they arrive on this stream
  /// unprompted.
  Future<void> init() async {
    if (!isSupported || _initialised) return;
    _initialised = true;
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => debugPrint('[iap] purchase stream error: $e'),
    );
    try {
      await loadProducts();
    } catch (e) {
      debugPrint('[iap] product load failed at init: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialised = false;
  }

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    try {
      return await _iap.isAvailable();
    } catch (e) {
      debugPrint('[iap] isAvailable failed: $e');
      return false;
    }
  }

  /// Why the last [loadProducts] came back short, for error reporting.
  String? _lastLoadDiagnostic;

  /// Fetch product details from the App Store. Returns the ids that loaded.
  Future<Set<String>> loadProducts() async {
    if (!isSupported) return <String>{};

    if (!await _iap.isAvailable()) {
      _lastLoadDiagnostic =
          'the App Store is unavailable on this device (not signed in to an '
          'Apple Account, or purchases are restricted)';
      debugPrint('[iap] ${_lastLoadDiagnostic!}');
      return _products.keys.toSet();
    }

    final response = await _iap.queryProductDetails(AppStoreProducts.allIds);
    for (final product in response.productDetails) {
      _products[product.id] = product;
    }

    _lastLoadDiagnostic = diagnoseProductLoad(
      requested: AppStoreProducts.allIds,
      notFoundIDs: response.notFoundIDs,
      errorCode: response.error?.code,
      errorText: response.error?.toString(),
    );
    if (_lastLoadDiagnostic != null) debugPrint('[iap] ${_lastLoadDiagnostic!}');

    return _products.keys.toSet();
  }

  /// Explain, in one line, why a product query came back short.
  ///
  /// Returns null when nothing was wrong.
  ///
  /// The subtle case is `storekit_no_response`, which reads like a platform
  /// malfunction but is not: the StoreKit 2 wrapper raises it whenever StoreKit
  /// hands back an EMPTY product list, and the plugin's catch then reports
  /// every requested id as not-found. It is therefore the same "these products
  /// don't exist" condition as an ordinary notFoundIDs result — and must not be
  /// reported as a generic error, which would bury the only explanation that
  /// actually helps.
  @visibleForTesting
  static String? diagnoseProductLoad({
    required Set<String> requested,
    required List<String> notFoundIDs,
    required String? errorCode,
    required String? errorText,
  }) {
    final noneExist =
        notFoundIDs.isNotEmpty || errorCode == 'storekit_no_response';
    if (noneExist) {
      final missing =
          notFoundIDs.isNotEmpty ? notFoundIDs.join(', ') : requested.join(', ');
      return 'the App Store knows no such products: $missing. '
          'Usual causes: they have not been created in App Store Connect yet; '
          'they are not at least "Ready to Submit"; the Paid Applications '
          'agreement is not active; or you are running without a StoreKit '
          'configuration file (see ios/Configuration.storekit — it only applies '
          'when launching from Xcode, NOT from `flutter run`)';
    }
    if (errorCode != null) {
      return 'queryProductDetails failed: ${errorText ?? errorCode}';
    }
    return null;
  }

  ProductDetails? productFor(String productId) => _products[productId];

  /// Localized store price (e.g. "£8.99"), or null if the product hasn't
  /// loaded. Always prefer this over a hardcoded price: the App Store charges
  /// in the user's own currency and tier.
  String? priceFor(String productId) => _products[productId]?.price;

  /// Localized total price for [coins], or null when it can't be determined.
  ///
  /// A coin purchase is a denomination bought several times over, so the total
  /// is the unit price times the quantity — [ProductDetails.price] alone is the
  /// price of ONE unit and would understate the charge. Formatted from
  /// `rawPrice` in the store's own currency rather than by multiplying the
  /// pre-formatted string.
  String? coinPriceFor(int coins) {
    final plan = AppStoreProducts.purchasePlanFor(coins);
    if (plan == null) return null;
    final product = _products[plan.pack.productId];
    if (product == null) return null;
    if (plan.quantity == 1) return product.price;
    return formatMoney(
      product.rawPrice * plan.quantity,
      currencyCode: product.currencyCode,
      currencySymbol: product.currencySymbol,
    );
  }

  /// Format [amount] the way the store would. Exposed for testing.
  @visibleForTesting
  static String formatMoney(
    double amount, {
    required String currencyCode,
    required String currencySymbol,
  }) {
    return NumberFormat.currency(
      // An empty or missing symbol would render a bare number; fall back to the
      // ISO code so the user always sees what they are being charged in.
      symbol: currencySymbol.isNotEmpty ? currencySymbol : '$currencyCode ',
      decimalDigits: 2,
    ).format(amount);
  }

  /// Buy [coins] FL Coins.
  ///
  /// StoreKit supports buying several units of one consumable in a single
  /// transaction, so any amount a denomination divides exactly is purchasable —
  /// the picker is not limited to fixed packs. The server recomputes the coins
  /// owed from the product id and quantity Apple signed, so the quantity sent
  /// here is a request, not a claim.
  Future<PurchaseOutcome> buyCoins(int coins) async {
    final plan = AppStoreProducts.purchasePlanFor(coins);
    if (plan == null) {
      debugPrint('[iap] $coins coins cannot be charged exactly by any denomination');
      return PurchaseOutcome.failed;
    }
    return _buy(plan.pack.productId, consumable: true, quantity: plan.quantity);
  }

  /// Buy (or change to) the Premium subscription.
  Future<PurchaseOutcome> buyPremium({required bool yearly}) =>
      _buy(AppStoreProducts.premiumFor(yearly: yearly), consumable: false);

  Future<PurchaseOutcome> _buy(
    String productId, {
    required bool consumable,
    int quantity = 1,
  }) async {
    if (!isSupported) return PurchaseOutcome.failed;
    await init();

    final userId = AppAuth.currentUserId;
    if (userId == null) {
      debugPrint('[iap] refusing to buy while signed out');
      return PurchaseOutcome.failed;
    }

    var product = _products[productId];
    if (product == null) {
      await loadProducts();
      product = _products[productId];
    }
    if (product == null) {
      debugPrint(
        '[iap] cannot buy $productId — it never loaded from the App Store. '
        '${_lastLoadDiagnostic ?? "no diagnostic recorded"}',
      );
      return PurchaseOutcome.failed;
    }

    // An in-flight purchase for the same product: reuse its future rather than
    // starting a second one, which StoreKit would reject anyway.
    final existing = _pending[productId];
    if (existing != null) return existing.future;

    final completer = Completer<PurchaseOutcome>();
    _pending[productId] = completer;

    // Sk2PurchaseParam rather than the generic PurchaseParam because only the
    // StoreKit-specific subclass carries `quantity` — the generic base class
    // has no such field, and passing it would silently buy a single unit.
    //
    // `applicationUserName` becomes StoreKit's `appAccountToken`, which Apple
    // signs into the transaction. It is how the server knows whose purchase
    // this is — the direct counterpart of Paddle's custom_data.user_id. It has
    // to be a UUID, which Supabase user ids already are.
    final param = Sk2PurchaseParam(
      productDetails: product,
      applicationUserName: userId,
      quantity: quantity,
    );

    try {
      final started = consumable
          // autoConsume MUST stay true here: the StoreKit implementation
          // asserts on it (`On iOS, we should always auto consume`), so
          // passing false crashes debug builds. It does not finish the
          // transaction early — that still happens in completePurchase, after
          // the server has fulfilled.
          ? await _iap.buyConsumable(purchaseParam: param, autoConsume: true)
          : await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _pending.remove(productId);
        return PurchaseOutcome.failed;
      }
    } catch (e) {
      debugPrint('[iap] buy($productId) threw: $e');
      _pending.remove(productId);
      return PurchaseOutcome.failed;
    }

    return completer.future;
  }

  /// Re-deliver subscriptions the user already owns (new device, reinstall).
  /// Apple requires this affordance for anything non-consumable.
  Future<void> restore() async {
    if (!isSupported) return;
    await init();
    try {
      await _iap.restorePurchases(applicationUserName: AppAuth.currentUserId);
    } catch (e) {
      debugPrint('[iap] restore failed: $e');
    }
  }

  // --- Purchase stream -------------------------------------------------------

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      await _handle(purchase);
    }
  }

  Future<void> _handle(PurchaseDetails purchase) async {
    final productId = purchase.productID;

    switch (purchase.status) {
      case PurchaseStatus.pending:
        // Ask to Buy / SCA. Nothing to do but wait for the next update.
        return;

      case PurchaseStatus.canceled:
        _finish(productId, PurchaseOutcome.cancelled);
        await _completeIfNeeded(purchase);
        return;

      case PurchaseStatus.error:
        debugPrint('[iap] purchase error for $productId: ${purchase.error}');
        _finish(productId, PurchaseOutcome.failed);
        // Complete it regardless: an errored transaction left unfinished is
        // redelivered forever and blocks the queue.
        await _completeIfNeeded(purchase);
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final verified = await _verifyWithServer(purchase);
        if (verified) {
          _finish(productId, PurchaseOutcome.success);
          // Only now is it safe to finish the transaction: until this point
          // StoreKit is our safety net for a purchase the server never applied.
          await _completeIfNeeded(purchase);
        } else {
          // Leave the transaction UNFINISHED so StoreKit hands it back on the
          // next launch, and let appstore-notifications apply it meanwhile.
          _finish(productId, PurchaseOutcome.pending);
        }
        return;
    }
  }

  void _finish(String productId, PurchaseOutcome outcome) {
    final completer = _pending.remove(productId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }

  Future<void> _completeIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('[iap] completePurchase failed for ${purchase.productID}: $e');
    }
  }

  /// Hand the Apple-signed transaction to `appstore-verify` for fulfilment.
  ///
  /// Returns true only when the server confirms it applied the purchase.
  Future<bool> _verifyWithServer(PurchaseDetails purchase) async {
    // Under StoreKit 2 this is the JWS representation of the transaction —
    // signed by Apple, so the server can trust what is inside it.
    final signedTransaction = purchase.verificationData.serverVerificationData;
    if (signedTransaction.isEmpty) {
      debugPrint('[iap] no serverVerificationData for ${purchase.productID}');
      return false;
    }

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'appstore-verify',
        body: <String, dynamic>{'signedTransaction': signedTransaction},
      );
      final ok = response.status >= 200 && response.status < 300;
      if (!ok) {
        debugPrint('[iap] appstore-verify ${response.status}: ${response.data}');
      }
      return ok;
    } catch (e) {
      debugPrint('[iap] appstore-verify call failed: $e');
      return false;
    }
  }
}
