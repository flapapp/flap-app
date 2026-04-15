/// Remote persistence for the profile feature (`public.user_profiles`).
abstract class ProfileRemoteDataSource {
  static const String kSelectFull =
      'id, first_name, last_name, username, display_name, email, phone, country, city, '
      'date_of_birth, position, experience, avatar_url, bio, profile_complete, friends_count, '
      'unread_notifications_count, created_at, updated_at, '
      'rating, match_rating, video_rating, total_matches, total_videos, matches, goals, assists, '
      'rating_history, coins, wins, losses, draws, settings, '
      'subscription, subscription_expiry, subscription_active, subscription_status, '
      'subscription_trial_end, subscription_auto_renew, subscription_started_at, '
      'champions_trial_used, subscription_price, max_challenges_per_month';

  Stream<Map<String, dynamic>> watchProfileRow(String userId);

  Future<Map<String, dynamic>?> fetchProfileRow(String userId);

  Future<void> mergeSettings(
    String userId,
    Map<String, dynamic> partial,
  );

  Stream<List<Map<String, dynamic>>> watchWalletTransactions(String userId);

  Future<void> completeProfile({
    required String userId,
    required Map<String, dynamic> payload,
  });

  Future<void> setAvatarUrl({
    required String userId,
    required String avatarUrl,
  });
}
