/// Remote persistence for subscription state on `public.profiles`.
abstract class SubscriptionRemoteDataSource {
  static const String kSelectSubscriptionFields =
      'id, subscription, subscription_expiry, subscription_active, subscription_status, '
      'subscription_trial_end, subscription_auto_renew, subscription_started_at, '
      'champions_trial_used, subscription_price, max_challenges_per_month';

  /// Ensures [userId] row has a normalized free tier when subscription is unset.
  Future<Map<String, dynamic>?> fetchProfileSubscriptionRow(String userId);

  Stream<Map<String, dynamic>> watchProfileSubscriptionRow(String userId);

  Future<void> updateProfileSubscription(String userId, Map<String, dynamic> patch);

  Future<void> creditCoinsForSubscriptionBonus({
    required int amount,
    required String description,
  });
}
