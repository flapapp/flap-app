import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/subscription/data/datasources/subscription_remote_data_source.dart';
import 'package:flap_app/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flap_app/models/subscription.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({required SubscriptionRemoteDataSource remote})
      : _remote = remote;

  final SubscriptionRemoteDataSource _remote;

  String? _resolveUserId([String? explicit]) =>
      explicit ?? AppAuthContext.userId;

  @override
  Future<Subscription?> getUserSubscription(String userId) async {
    final row = await _remote.fetchProfileSubscriptionRow(userId);
    if (row == null) return null;
    return Subscription.fromProfileRow(row, userId: userId);
  }

  @override
  Stream<Subscription?> watchUserSubscription(String userId) {
    return _remote.watchProfileSubscriptionRow(userId).map((row) {
      if (row.isEmpty) return null;
      return Subscription.fromProfileRow(row, userId: userId);
    });
  }

  @override
  Future<bool> hasActiveSubscription([String? userId]) async {
    userId = _resolveUserId(userId);
    if (userId == null) return false;

    final subscription = await getUserSubscription(userId);
    return subscription != null &&
        subscription.isActive &&
        subscription.type != SubscriptionType.free;
  }

  @override
  Future<SubscriptionType> getSubscriptionType([String? userId]) async {
    userId = _resolveUserId(userId);
    if (userId == null) return SubscriptionType.free;

    final subscription = await getUserSubscription(userId);
    return subscription?.type ?? SubscriptionType.free;
  }

  Future<void> _awardMonthlyCoins(String userId, SubscriptionType type) async {
    final coinsToAward = switch (type) {
      SubscriptionType.europa => 30,
      SubscriptionType.champions => 60,
      SubscriptionType.free => 0,
    };
    if (coinsToAward <= 0) return;

    await _remote.creditCoinsForSubscriptionBonus(
      amount: coinsToAward,
      description: I18n.inline(
        'Місячний бонус за підписку',
        'Monthly bonus for subscription',
      ),
    );
  }

  @override
  Future<Subscription?> startChampionsTrialSubscription() async {
    final userId = _resolveUserId();
    if (userId == null) {
      throw Exception('Користувач не авторизований');
    }

    final row = await _remote.fetchProfileSubscriptionRow(userId);
    if (row == null) {
      throw Exception('Профіль не знайдено');
    }
    if (row['champions_trial_used'] == true) {
      throw Exception('Ви вже використали пробний період');
    }

    final now = DateTime.now();
    final trialEnd = now.add(const Duration(days: 30));

    await _remote.updateProfileSubscription(userId, {
      'subscription': Subscription.typeToDb(SubscriptionType.champions),
      'subscription_status': 'trial',
      'subscription_started_at': now.toUtc().toIso8601String(),
      'subscription_expiry': trialEnd.toUtc().toIso8601String(),
      'subscription_trial_end': trialEnd.toUtc().toIso8601String(),
      'subscription_active': true,
      'subscription_auto_renew': false,
      'subscription_price': 0,
      'champions_trial_used': true,
      'max_challenges_per_month': 999,
    });

    await _awardMonthlyCoins(userId, SubscriptionType.champions);

    final refreshed = await _remote.fetchProfileSubscriptionRow(userId);
    if (refreshed == null) return null;
    return Subscription.fromProfileRow(refreshed, userId: userId);
  }

  @override
  Future<Subscription?> purchaseSubscription(SubscriptionType type) async {
    final userId = _resolveUserId();
    if (userId == null) {
      throw Exception('Користувач не авторизований');
    }

    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 30));
    final price = type == SubscriptionType.europa ? 49 : 89;
    final maxChallenges = type == SubscriptionType.champions ? 999 : 5;

    await _remote.updateProfileSubscription(userId, {
      'subscription': Subscription.typeToDb(type),
      'subscription_status': 'active',
      'subscription_started_at': now.toUtc().toIso8601String(),
      'subscription_expiry': endDate.toUtc().toIso8601String(),
      'subscription_trial_end': null,
      'subscription_active': true,
      'subscription_auto_renew': true,
      'subscription_price': price,
      'max_challenges_per_month': maxChallenges,
    });

    if (type != SubscriptionType.free) {
      await _awardMonthlyCoins(userId, type);
    }

    final refreshed = await _remote.fetchProfileSubscriptionRow(userId);
    if (refreshed == null) return null;
    return Subscription.fromProfileRow(refreshed, userId: userId);
  }

  Future<void> _applyFreeTier(String userId) async {
    final now = DateTime.now();
    final far = now.add(const Duration(days: 365 * 10));
    await _remote.updateProfileSubscription(userId, {
      'subscription': Subscription.typeToDb(SubscriptionType.free),
      'subscription_status': 'active',
      'subscription_started_at': now.toUtc().toIso8601String(),
      'subscription_expiry': far.toUtc().toIso8601String(),
      'subscription_trial_end': null,
      'subscription_active': true,
      'subscription_auto_renew': false,
      'subscription_price': 0,
      'max_challenges_per_month': 1,
    });
  }

  @override
  Future<void> cancelSubscription() async {
    final userId = _resolveUserId();
    if (userId == null) {
      throw Exception('Користувач не авторизований');
    }

    final subscription = await getUserSubscription(userId);
    if (subscription == null || subscription.type == SubscriptionType.free) {
      throw Exception('У вас немає активної підписки');
    }

    await _remote.updateProfileSubscription(userId, {
      'subscription_status': 'cancelled',
      'subscription_auto_renew': false,
    });

    await _applyFreeTier(userId);
  }

  @override
  Future<bool> hasFeature(String feature, [String? userId]) async {
    userId = _resolveUserId(userId);
    if (userId == null) return false;

    final subscription = await getUserSubscription(userId);
    return subscription?.hasFeature(feature) ?? false;
  }

  @override
  Future<int> getChallengeLimit([String? userId]) async {
    userId = _resolveUserId(userId);
    if (userId == null) return 1;

    final subscription = await getUserSubscription(userId);
    switch (subscription?.type ?? SubscriptionType.free) {
      case SubscriptionType.champions:
        return -1;
      case SubscriptionType.europa:
        return 5;
      default:
        return 1;
    }
  }

  @override
  Future<bool> canCreateChallenge([String? userId]) async {
    userId = _resolveUserId(userId);
    if (userId == null) return false;

    final limit = await getChallengeLimit(userId);
    if (limit == -1) return true;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final isoStart = monthStart.toUtc().toIso8601String();

    final rows = await Supabase.instance.client
        .from('challenges')
        .select('id')
        .eq('creator_id', userId)
        .gte('created_at', isoStart);
    final challengesCount = (rows as List).length;

    return challengesCount < limit;
  }

  @override
  String getSubscriptionBenefits(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return 'Europa League: Розширені можливості, 5 челенджів/місяць, +30 монет';
      case SubscriptionType.champions:
        return 'Champions League: Преміум досвід, необмежені челенджі, +60 монет';
      default:
        return 'Безкоштовна: Базовий функціонал, 1 челендж/місяць';
    }
  }

  @override
  Future<Subscription?> getCurrent() async {
    final userId = _resolveUserId();
    if (userId == null) return null;
    return getUserSubscription(userId);
  }

  @override
  Future<void> grantChampionsTrialIfMissing() async {
    final userId = _resolveUserId();
    if (userId == null) return;

    final subscription = await getUserSubscription(userId);
    if (subscription != null && subscription.type != SubscriptionType.free) {
      return;
    }

    try {
      await startChampionsTrialSubscription();
    } catch (_) {}
  }

  @override
  Future<Subscription?> getActiveSubscription() async {
    final userId = _resolveUserId();
    if (userId == null) return null;
    return getUserSubscription(userId);
  }
}
