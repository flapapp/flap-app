import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/coin_ledger.dart';
import '../../data/models/subscription.dart';

class SubscriptionService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get user's current subscription
  Future<Subscription?> getUserSubscription(String userId) async {
    try {
      final row = await _activeSubscriptionRow(userId);
      if (row == null) {
        // Create default free subscription
        return await _createFreeSubscription(userId);
      }
      return _toSubscription(row);
    } catch (e) {
      print('Error getting user subscription: $e');
      try {
        return await _createFreeSubscription(userId);
      } catch (createError) {
        print('Failed to create fallback free subscription: $createError');
        return null;
      }
    }
  }

  // Get user subscription stream
  Stream<Subscription?> getUserSubscriptionStream(String userId) {
    return _client
        .from('subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('starts_at', ascending: false)
        .map((rows) {
          final active = rows
              .where((row) => row['status'] == 'trial' || row['status'] == 'active')
              .toList(growable: false);
          if (active.isEmpty) {
            return null;
          }
          return _toSubscription(active.first);
        });
  }

  // Check if user has active subscription
  Future<bool> hasActiveSubscription([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;

    final subscription = await getUserSubscription(userId);
    return subscription != null && 
           subscription.isActive && 
           subscription.type != SubscriptionType.free;
  }

  // Get subscription type
  Future<SubscriptionType> getSubscriptionType([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return SubscriptionType.free;

    final subscription = await getUserSubscription(userId);
    return subscription?.type ?? SubscriptionType.free;
  }

  // Create free subscription for new users
  Future<Subscription> _createFreeSubscription(String userId) async {
    final planId = await _resolvePlanId(SubscriptionType.free);
    final now = DateTime.now();
    final subscription = Subscription(
      id: '',
      userId: userId,
      type: SubscriptionType.free,
      status: SubscriptionStatus.active,
      startDate: now,
      endDate: now.add(const Duration(days: 365 * 10)), // 10 years
      price: 0,
      isActive: true,
      features: {},
    );

    final inserted = await _client
        .from('subscriptions')
        .insert(subscription.toSupabase(planId))
        .select('id')
        .single();
    return subscription.copyWith(id: inserted['id'].toString());
  }

  // Start Champions League trial
  Future<Subscription?> startChampionsTrialSubscription() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }

      // Check if user already had trial
      final existingSubscriptions = await _client
          .from('subscriptions')
          .select('trial_ends_at, subscription_plans!inner(code)')
          .eq('user_id', currentUser.id)
          .eq('subscription_plans.code', 'champions');

      for (final row in existingSubscriptions as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        if (map['trial_ends_at'] != null) {
          throw Exception(tr('subscription_error_trial_already_used'));
        }
      }

      // Deactivate current subscription
      await _deactivateCurrentSubscription(currentUser.id);
      final planId = await _resolvePlanId(SubscriptionType.champions);

      // Create trial subscription
      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: 30)); // 30 days trial
      
      final subscription = Subscription(
        id: '',
        userId: currentUser.id,
        type: SubscriptionType.champions,
        status: SubscriptionStatus.trial,
        startDate: now,
        endDate: trialEndDate,
        price: 0,
        isActive: true,
        trialEndDate: trialEndDate,
        features: {},
      );

      final inserted = await _client
          .from('subscriptions')
          .insert(subscription.toSupabase(planId))
          .select('id')
          .single();
      final newSubscription = subscription.copyWith(id: inserted['id'].toString());

      // Award trial coins
      await _awardMonthlyCoins(currentUser.id, SubscriptionType.champions);

      return newSubscription;
    } catch (e) {
      print('Error starting trial subscription: $e');
      rethrow;
    }
  }

  // Purchase subscription (mock implementation)
  Future<Subscription?> purchaseSubscription(SubscriptionType type) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }

      // Deactivate current subscription
      await _deactivateCurrentSubscription(currentUser.id);
      final planId = await _resolvePlanId(type);

      // Create new subscription
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30)); // 30 days
      
      final subscription = Subscription(
        id: '',
        userId: currentUser.id,
        type: type,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: endDate,
        price: type == SubscriptionType.europa ? 49 : 89,
        isActive: true,
        autoRenew: true,
        features: {},
      );

      final inserted = await _client
          .from('subscriptions')
          .insert(subscription.toSupabase(planId))
          .select('id')
          .single();
      final newSubscription = subscription.copyWith(id: inserted['id'].toString());

      // Award monthly coins
      await _awardMonthlyCoins(currentUser.id, type);

      return newSubscription;
    } catch (e) {
      print('Error purchasing subscription: $e');
      rethrow;
    }
  }

  // Deactivate current subscription
  Future<void> _deactivateCurrentSubscription(String userId) async {
    await _client
        .from('subscriptions')
        .update({'status': 'expired'})
        .eq('user_id', userId)
        .inFilter('status', ['trial', 'active']);
  }

  // Award monthly coins based on subscription type
  Future<void> _awardMonthlyCoins(String userId, SubscriptionType type) async {
    int coinsToAward = 0;
    
    switch (type) {
      case SubscriptionType.europa:
        coinsToAward = 30;
        break;
      case SubscriptionType.champions:
        coinsToAward = 60;
        break;
      default:
        return;
    }

    if (coinsToAward > 0) {
      await insertCoinTransaction(
        Supabase.instance.client,
        userId,
        'subscription_bonus',
        coinsToAward,
        tr('il_c4dbbb91b5'),
      );
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception(tr('submission_error_not_signed_in'));
      }

      final subscription = await getUserSubscription(currentUser.id);
      if (subscription == null || subscription.type == SubscriptionType.free) {
        throw Exception(tr('subscription_error_no_active_subscription'));
      }

      // Update subscription status
      await _client
          .from('subscriptions')
          .update({
            'status': 'cancelled',
            'auto_renew': false,
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', subscription.id);

      // Create free subscription
      await _createFreeSubscription(currentUser.id);
    } catch (e) {
      print('Error cancelling subscription: $e');
      rethrow;
    }
  }

  // Check if feature is available for user
  Future<bool> hasFeature(String feature, [String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;

    final subscription = await getUserSubscription(userId);
    return subscription?.hasFeature(feature) ?? false;
  }

  // Get challenge limit for user
  Future<int> getChallengeLimit([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return 1;

    final subscription = await getUserSubscription(userId);
    switch (subscription?.type ?? SubscriptionType.free) {
      case SubscriptionType.champions:
        return -1; // Unlimited
      case SubscriptionType.europa:
        return 5;
      default:
        return 1;
    }
  }

  // Check if user can create more challenges this month
  Future<bool> canCreateChallenge([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;

    final limit = await getChallengeLimit(userId);
    if (limit == -1) return true; // Unlimited

    // Count challenges created this month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    final rows = await _client
        .from('challenges')
        .select('id')
        .eq('creator_id', userId)
        .gte('created_at', monthStart.toUtc().toIso8601String());

    return (rows as List<dynamic>).length < limit;
  }

  // Get subscription benefits text
  String getSubscriptionBenefits(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return tr('subscription_benefits_europa');
      case SubscriptionType.champions:
        return tr('subscription_benefits_champions');
      default:
        return tr('subscription_benefits_free');
    }
  }

  // LEGACY METHODS FOR COMPATIBILITY
  Future<Subscription?> getCurrent() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) return null;
    return getUserSubscription(userId);
  }

  Future<void> grantChampionsTrialIfMissing() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) return;

    try {
      final subscription = await getUserSubscription(userId);
      if (subscription != null && subscription.type != SubscriptionType.free) return;

      await startChampionsTrialSubscription();
    } catch (e) {
      print('Failed to grant champions trial during bootstrap: $e');
    }
  }

  Future<Subscription?> getActiveSubscription() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) return null;
    return getUserSubscription(userId);
  }

  Future<Map<String, dynamic>?> _activeSubscriptionRow(String userId) async {
    return await _client
        .from('subscriptions')
        .select('*, subscription_plans(code, price_monthly)')
        .eq('user_id', userId)
        .inFilter('status', ['trial', 'active'])
        .order('starts_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Subscription _toSubscription(Map<String, dynamic> row) {
    final plan = row['subscription_plans'] as Map<String, dynamic>?;
    final code = (plan?['code'] ?? 'free').toString();
    return Subscription.fromSupabase(row: row, planCode: _normalizePlanCode(code));
  }

  String _normalizePlanCode(String code) {
    if (code == 'champions_league') return 'champions';
    return code;
  }

  String _planCodeForType(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.champions:
        return 'champions';
      case SubscriptionType.europa:
        return 'europa';
      case SubscriptionType.free:
        return 'free';
    }
  }

  Future<String> _resolvePlanId(SubscriptionType type) async {
    final code = _planCodeForType(type);
    final row = await _client
        .from('subscription_plans')
        .select('id, code')
        .eq('code', code)
        .maybeSingle();
    if (row != null) {
      return row['id'].toString();
    }
    if (type == SubscriptionType.champions) {
      final alt = await _client
          .from('subscription_plans')
          .select('id, code')
          .eq('code', 'champions_league')
          .maybeSingle();
      if (alt != null) {
        return alt['id'].toString();
      }
    }
    throw Exception('Subscription plan "$code" not found');
  }
}