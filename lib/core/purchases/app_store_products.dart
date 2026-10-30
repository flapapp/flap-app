/// App Store (StoreKit) product identifiers for iOS in-app purchases.
///
/// iOS sells Premium and FL Coins through StoreKit because App Store guideline
/// 3.1.1 requires in-app purchase for digital content; Android and web keep
/// using Paddle. These ids must match App Store Connect EXACTLY — a typo shows
/// up as a product that simply never loads.
///
/// This list is mirrored by `PRODUCTS` in
/// `supabase/functions/_shared/appstore.ts`. The server's copy is the
/// authoritative one: it decides how many coins a purchase is worth, from a
/// product id Apple signed. The copy here is for DISPLAY and for asking
/// StoreKit which products to fetch — it never determines what a user receives.
library;

/// A consumable FL Coin product.
class CoinPack {
  const CoinPack({required this.productId, required this.coins});

  final String productId;

  /// Coins this pack grants. Kept in step with the server catalog; at $1 per 10
  /// coins this also implies the price tier the product needs in App Store
  /// Connect (100 coins -> $10).
  final int coins;
}

abstract final class AppStoreProducts {
  static const String premiumMonthly = 'com.flap.flapapp.premium.monthly';
  static const String premiumYearly = 'com.flap.flapapp.premium.yearly';

  /// Coin denominations, smallest first.
  ///
  /// StoreKit *does* support buying several units of one consumable in a single
  /// transaction (`Sk2PurchaseParam.quantity`), so the buy screen keeps the
  /// same free-form picker Paddle uses — these are denominations, not a menu.
  /// [purchasePlanFor] picks which one to charge.
  ///
  /// Several denominations exist rather than just the 10-coin unit because
  /// Apple caps the quantity of a single purchase. Buying 500 coins as
  /// `coins.500 x 1` instead of `coins.10 x 50` keeps the quantity far below
  /// any plausible cap.
  static const List<CoinPack> coinPacks = <CoinPack>[
    CoinPack(productId: 'com.flap.flapapp.coins.10', coins: 10),
    CoinPack(productId: 'com.flap.flapapp.coins.50', coins: 50),
    CoinPack(productId: 'com.flap.flapapp.coins.100', coins: 100),
    CoinPack(productId: 'com.flap.flapapp.coins.500', coins: 500),
    CoinPack(productId: 'com.flap.flapapp.coins.1000', coins: 1000),
  ];

  /// Largest number of units a single StoreKit purchase may ask for.
  ///
  /// Apple caps this, and the exact number is NOT something we have confirmed —
  /// their documentation on it could not be verified, so this is deliberately
  /// conservative. [purchasePlanFor] keeps quantities well under it by paying
  /// with the largest denomination that fits, so this only bites on unusual
  /// amounts (e.g. 370 coins, which no denomination above 10 divides).
  ///
  /// If a large purchase is ever rejected by StoreKit, lower this; if a sandbox
  /// test proves a higher ceiling, raise it.
  static const int maxQuantity = 10;

  /// How to charge for [coins]: which denomination, and how many of it.
  ///
  /// Picks the largest denomination that divides [coins] exactly and stays
  /// within [maxQuantity], which minimises the quantity actually sent to
  /// StoreKit. Returns null when [coins] cannot be paid for exactly — the
  /// caller must not silently charge a different amount.
  static ({CoinPack pack, int quantity})? purchasePlanFor(int coins) {
    if (coins <= 0) return null;
    // Largest first: the biggest denomination gives the smallest quantity.
    for (final pack in coinPacks.reversed) {
      if (coins % pack.coins != 0) continue;
      final quantity = coins ~/ pack.coins;
      if (quantity <= maxQuantity) return (pack: pack, quantity: quantity);
    }
    return null;
  }

  /// Every coin amount [purchasePlanFor] can charge for exactly, ascending.
  /// The buy screen uses this to keep its picker on amounts that can be bought.
  static List<int> get buyableCoinAmounts {
    final amounts = <int>{};
    for (final pack in coinPacks) {
      for (var q = 1; q <= maxQuantity; q++) {
        amounts.add(pack.coins * q);
      }
    }
    return amounts.toList()..sort();
  }

  static String premiumFor({required bool yearly}) =>
      yearly ? premiumYearly : premiumMonthly;

  static CoinPack? packForProductId(String productId) {
    for (final pack in coinPacks) {
      if (pack.productId == productId) return pack;
    }
    return null;
  }

  /// Every id StoreKit should be asked to load.
  static Set<String> get allIds => <String>{
        premiumMonthly,
        premiumYearly,
        for (final pack in coinPacks) pack.productId,
      };

  static Set<String> get premiumIds => <String>{premiumMonthly, premiumYearly};
}
