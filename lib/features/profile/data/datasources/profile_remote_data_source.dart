/// Remote persistence for the profile feature (`public.profiles`).
abstract class ProfileRemoteDataSource {
  static const String kSelectFull =
      'id, name, surname, display_name, email, phone, city, age, position, experience, '
      'avatar_url, rating, match_rating, video_rating, total_matches, total_videos, '
      'matches, goals, assists, rating_history, coins, wins, losses, draws, settings, '
      'subscription, profile_complete, updated_at';

  Stream<Map<String, dynamic>> watchProfileRow(String userId);

  Future<Map<String, dynamic>?> fetchProfileRow(String userId);

  Future<void> mergeSettings(
    String userId,
    Map<String, dynamic> partial,
  );

  Stream<List<Map<String, dynamic>>> watchWalletTransactions(String userId);
}
