import 'dart:io';

import 'package:flap_app/core/purchases/app_store_products.dart';
import 'package:flap_app/features/coins/data/coin_purchase_service.dart';
import 'package:flap_app/features/subscriptions/data/paddle_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// The App Store product catalog exists twice — here in Dart (for display and
/// for asking StoreKit what to load) and in
/// `supabase/functions/_shared/appstore.ts` (which decides what a purchase is
/// actually worth). They are in different languages and deploy separately, so
/// nothing but a test stops them drifting. A drift is expensive: a product the
/// server doesn't know about is a payment taken and nothing delivered.
void main() {
  final serverCatalog = File(
    'supabase/functions/_shared/appstore.ts',
  ).readAsStringSync();

  /// Coin products the server recognises: product id -> coins granted.
  Map<String, int> serverCoinProducts() {
    final re = RegExp(
      r'"([\w.]+)":\s*\{\s*kind:\s*"coins",\s*coins:\s*(\d+)\s*\}',
    );
    return <String, int>{
      for (final m in re.allMatches(serverCatalog))
        m.group(1)!: int.parse(m.group(2)!),
    };
  }

  /// Premium products the server recognises: product id -> billing interval.
  Map<String, String> serverPremiumProducts() {
    final re = RegExp(
      r'"([\w.]+)":\s*\{\s*kind:\s*"premium",\s*interval:\s*"(\w+)"\s*\}',
    );
    return <String, String>{
      for (final m in re.allMatches(serverCatalog)) m.group(1)!: m.group(2)!,
    };
  }

  test('the regexes actually find the server catalog', () {
    // Guards the tests below: if the TS file is reformatted so these stop
    // matching, every other assertion would pass vacuously.
    expect(serverCoinProducts(), isNotEmpty);
    expect(serverPremiumProducts(), isNotEmpty);
  });

  test('every coin pack exists on the server and grants the same coins', () {
    final server = serverCoinProducts();
    for (final pack in AppStoreProducts.coinPacks) {
      expect(
        server,
        contains(pack.productId),
        reason: '${pack.productId} is offered in the app but unknown to the '
            'server — buying it would charge the user and credit nothing',
      );
      expect(
        server[pack.productId],
        pack.coins,
        reason: '${pack.productId} grants ${pack.coins} coins in the app but '
            '${server[pack.productId]} on the server',
      );
    }
  });

  test('the server offers no coin product the app cannot show', () {
    final appIds = AppStoreProducts.coinPacks.map((p) => p.productId).toSet();
    expect(serverCoinProducts().keys.toSet(), appIds);
  });

  test('premium product ids match the server, per interval', () {
    final server = serverPremiumProducts();
    expect(server[AppStoreProducts.premiumMonthly], 'monthly');
    expect(server[AppStoreProducts.premiumYearly], 'yearly');
    expect(server.keys.toSet(), AppStoreProducts.premiumIds);
  });

  test('a pack id encodes the coins it grants', () {
    // The server derives nothing from the id, but a mismatch here means the
    // catalogs disagree in a way that is easy to miss by eye.
    for (final pack in AppStoreProducts.coinPacks) {
      expect(pack.productId, 'com.flap.flapapp.coins.${pack.coins}');
    }
  });

  test('allIds covers every product the app can buy', () {
    expect(
      AppStoreProducts.allIds,
      {
        AppStoreProducts.premiumMonthly,
        AppStoreProducts.premiumYearly,
        ...AppStoreProducts.coinPacks.map((p) => p.productId),
      },
    );
  });

  test('packs are ordered cheapest first and never repeat an amount', () {
    final coins = AppStoreProducts.coinPacks.map((p) => p.coins).toList();
    expect(coins, List<int>.from(coins)..sort());
    expect(coins.toSet().length, coins.length);
  });

  test('packForProductId round-trips, and rejects unknown ids', () {
    for (final pack in AppStoreProducts.coinPacks) {
      expect(AppStoreProducts.packForProductId(pack.productId)?.coins, pack.coins);
    }
    expect(AppStoreProducts.packForProductId('com.flap.flapapp.coins.7'), isNull);
    expect(AppStoreProducts.packForProductId(''), isNull);
  });

  test('premiumFor picks the interval it is asked for', () {
    expect(AppStoreProducts.premiumFor(yearly: true), AppStoreProducts.premiumYearly);
    expect(AppStoreProducts.premiumFor(yearly: false), AppStoreProducts.premiumMonthly);
  });

  group('purchasePlanFor', () {
    test('never charges for a different amount than requested', () {
      // The invariant that matters: denomination x quantity must equal exactly
      // what the user asked for. Anything else silently over- or under-charges.
      for (final coins in AppStoreProducts.buyableCoinAmounts) {
        final plan = AppStoreProducts.purchasePlanFor(coins);
        expect(plan, isNotNull, reason: '$coins is advertised as buyable');
        expect(
          plan!.pack.coins * plan.quantity,
          coins,
          reason: '$coins would be charged as ${plan.pack.coins} x ${plan.quantity}',
        );
      }
    });

    test('stays within the quantity cap', () {
      for (final coins in AppStoreProducts.buyableCoinAmounts) {
        final plan = AppStoreProducts.purchasePlanFor(coins)!;
        expect(plan.quantity, lessThanOrEqualTo(AppStoreProducts.maxQuantity));
        expect(plan.quantity, greaterThanOrEqualTo(1));
      }
    });

    test('prefers the largest denomination, keeping quantity small', () {
      // Paying 500 as 500x1 rather than 10x50 is the whole point: it keeps us
      // far away from Apple's per-purchase quantity cap.
      expect(AppStoreProducts.purchasePlanFor(500)!.pack.coins, 500);
      expect(AppStoreProducts.purchasePlanFor(500)!.quantity, 1);
      expect(AppStoreProducts.purchasePlanFor(1000)!.pack.coins, 1000);
      expect(AppStoreProducts.purchasePlanFor(300)!.pack.coins, 100);
      expect(AppStoreProducts.purchasePlanFor(300)!.quantity, 3);
      expect(AppStoreProducts.purchasePlanFor(150)!.pack.coins, 50);
      expect(AppStoreProducts.purchasePlanFor(30)!.pack.coins, 10);
    });

    test('refuses amounts no denomination can charge exactly', () {
      // 370 is a multiple of 10, but 37 x the 10-coin unit exceeds the cap and
      // nothing larger divides it. Refusing beats charging the wrong amount.
      expect(AppStoreProducts.purchasePlanFor(370), isNull);
      expect(AppStoreProducts.purchasePlanFor(7), isNull);
      expect(AppStoreProducts.purchasePlanFor(0), isNull);
      expect(AppStoreProducts.purchasePlanFor(-100), isNull);
    });

    test('buyableCoinAmounts is exactly the set that resolves to a plan', () {
      final advertised = AppStoreProducts.buyableCoinAmounts;
      expect(advertised, isNotEmpty);
      // Ascending and unique.
      expect(advertised, List<int>.from(advertised)..sort());
      expect(advertised.toSet().length, advertised.length);
      // Nothing buyable is missing from the list: sweep the whole range.
      for (var coins = 10; coins <= advertised.last; coins += 10) {
        final plan = AppStoreProducts.purchasePlanFor(coins);
        expect(
          plan != null,
          advertised.contains(coins),
          reason: '$coins: plan=${plan != null} but advertised='
              '${advertised.contains(coins)}',
        );
      }
    });

    test('covers the amounts the buy screen promotes', () {
      // Read the real chip list rather than a copy of it: a preset that has no
      // plan is a chip that does nothing when tapped on iOS.
      expect(CoinMath.presets, isNotEmpty);
      for (final coins in CoinMath.presets) {
        expect(AppStoreProducts.purchasePlanFor(coins), isNotNull, reason: '$coins');
        // A preset should be a denomination outright, not a multiple of a
        // smaller one — that is what keeps the headline amounts at quantity 1.
        expect(AppStoreProducts.purchasePlanFor(coins)!.quantity, 1, reason: '$coins');
      }
    });

    test('presets stay inside the picker bounds', () {
      for (final coins in CoinMath.presets) {
        expect(coins, greaterThanOrEqualTo(PaddleConfig.minCoins), reason: '$coins');
        expect(coins, lessThanOrEqualTo(PaddleConfig.maxCoins), reason: '$coins');
        expect(coins % PaddleConfig.coinStep, 0, reason: '$coins');
      }
    });
  });
}
