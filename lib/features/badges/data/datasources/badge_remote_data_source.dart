abstract class BadgeRemoteDataSource {
  Future<void> upsertDefaultBadges(List<Map<String, dynamic>> rows);

  Future<List<Map<String, dynamic>>> fetchAvailableBadges();

  Future<List<Map<String, dynamic>>> fetchBadgesByCategory(String category);

  Future<List<String>> fetchUserBadgeIds(String userId);

  Future<int> fetchUserCoins(String userId);

  Future<void> rpcPurchaseBadge(String badgeId);

  Future<bool> rpcAwardBadge({
    required String userId,
    required String badgeId,
    required String reason,
  });

  Future<Map<String, dynamic>?> fetchBadgeRow(String badgeId);

  Future<Map<String, dynamic>?> fetchProfileActivityRow(String userId);
}
