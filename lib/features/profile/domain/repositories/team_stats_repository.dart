/// Live `teamStats/{teamId}` snapshot for UI streams.
abstract class TeamStatsRepository {
  Stream<Map<String, dynamic>?> watchTeamStats(String teamId);
}
