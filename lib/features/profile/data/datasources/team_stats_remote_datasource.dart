/// Live team stats snapshot (derived / stored; Supabase-backed).
abstract class TeamStatsRemoteDataSource {
  Stream<Map<String, dynamic>?> watchTeamStats(String teamId);
}
