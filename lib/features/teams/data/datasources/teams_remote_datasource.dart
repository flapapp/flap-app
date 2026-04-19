/// Remote access for team rows + membership (Supabase).
abstract class TeamsRemoteDataSource {
  Stream<Map<String, dynamic>?> watchTeamDocument(String teamId);

  Stream<List<Map<String, dynamic>>> watchTeamsOrderedByWins();

  Stream<List<Map<String, dynamic>>> watchTeamStatsCollection();
}
