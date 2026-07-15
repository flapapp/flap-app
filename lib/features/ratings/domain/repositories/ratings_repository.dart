/// Player and video ratings, leaderboards, and recompute helpers (domain).
abstract class RatingsRepository {
  Future<void> updateVideoAggregate(String videoId);

  Future<double> getUserRating(String userId);

  Future<Map<String, dynamic>> getUserRatingStats(String userId);

  Future<void> ratePlayerAfterMatch({
    required String matchId,
    required String playerId,
    required String ratedBy,
    required Map<String, double> criteria,
  });

  Future<bool> rateVideo({
    required String videoId,
    required String ratedBy,
    required Map<String, double> criteria,
  });

  String getPlayerLevel(double rating);

  int getPlayerLevelColor(double rating);

  Future<void> createUserWithDefaultRating(
    String userId,
    Map<String, dynamic> userData,
  );

  double getDefaultRating();

  Future<void> recomputeOverallRating(
    String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  });

  Future<void> recomputeForMatchParticipants(String matchId);

  Future<void> recomputeAllUsers({int pageSize = 200});

  Future<List<Map<String, dynamic>>> getTopPlayers({
    int limit = 50,
    String? city,
    String? position,
  });
}
