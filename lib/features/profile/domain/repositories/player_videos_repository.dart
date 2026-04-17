/// User video listing for profile and rating-request flows.
abstract class PlayerVideosRepository {
  Future<List<Map<String, dynamic>>> listVideosForUser(String userId, int limit);

  /// Videos owned by the signed-in user (for rating-request dialog).
  Future<List<Map<String, dynamic>>> listMyVideos(int limit);

  Future<List<String>> listMyVideoIds(int limit);
}
