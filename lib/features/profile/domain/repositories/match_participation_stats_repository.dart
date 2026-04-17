/// Finished-match W/D/L + recent form for a user (domain).
abstract class MatchParticipationStatsRepository {
  Future<Map<String, dynamic>> loadFinishedMatchStats(String userId);
}
