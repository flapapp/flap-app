/// `videos` collection queries (data layer).
abstract class PlayerVideosRemoteDataSource {
  Future<List<Map<String, dynamic>>> listByUserId(String userId, int limit);

  Future<List<String>> listVideoIdsForUser(String userId, int limit);
}
