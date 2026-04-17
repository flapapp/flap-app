/// Aggregated W/D/L and recent form from `matches` (data layer).
abstract class MatchParticipationStatsRemoteDataSource {
  Future<Map<String, dynamic>> loadFinishedMatchStats(String userId);
}
