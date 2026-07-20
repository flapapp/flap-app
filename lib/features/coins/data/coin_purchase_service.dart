import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/coin_ledger.dart';
import '../../subscriptions/data/paddle_config.dart';

/// Pure helpers mapping between an FL Coin amount and the Paddle order that
/// buys it. Coins are always a whole number of $1 units
/// ([PaddleConfig.coinsPerUnit] each), so every amount here is a multiple of
/// [PaddleConfig.coinStep].
abstract final class CoinMath {
  /// Quick-select amounts shown as chips. All within the min/max bounds.
  static const List<int> presets = <int>[10, 50, 100, 500];

  /// Snaps [coins] to the nearest valid amount: a multiple of the step, clamped
  /// to [PaddleConfig.minCoins]..[PaddleConfig.maxCoins].
  static int normalize(int coins) {
    final stepped =
        (coins / PaddleConfig.coinStep).round() * PaddleConfig.coinStep;
    return stepped.clamp(PaddleConfig.minCoins, PaddleConfig.maxCoins);
  }

  /// The Paddle checkout quantity (number of $1 units) for [coins].
  static int unitsFor(int coins) => coins ~/ PaddleConfig.coinsPerUnit;

  /// Price in whole USD for [coins]. Always exact because coins is a multiple
  /// of the per-dollar rate.
  static int priceUsd(int coins) => unitsFor(coins);
}

/// Reads the coin balance and waits for a Paddle purchase to land.
class CoinPurchaseService {
  CoinPurchaseService(this._client);

  final SupabaseClient _client;

  Future<int> balance(String userId) => coinBalance(_client, userId);

  /// Polls the ledger until the balance rises above [previousBalance].
  ///
  /// Coins are credited by the `paddle-webhook` edge function, which Paddle
  /// calls out-of-band — so a successful checkout does NOT mean the coins have
  /// landed yet. Returns the new balance, or null if nothing arrived before the
  /// timeout (the credit may still land later; the caller should say so rather
  /// than claim the purchase failed).
  Future<int?> awaitCredit(
    String userId, {
    required int previousBalance,
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      try {
        final current = await balance(userId);
        if (current > previousBalance) return current;
      } catch (_) {
        // Transient read failure — keep polling until the deadline.
      }
    }
    return null;
  }
}
