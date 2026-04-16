abstract class TournamentsRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchTournaments();

  Future<String> insertTournament({
    required String name,
    required String type,
    int? maxTeams,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? rules,
  });

  Future<List<Map<String, dynamic>>> fetchMatches(String tournamentId);

  Future<List<Map<String, dynamic>>> fetchTeamsByIds(List<String> teamIds);

  Future<List<Map<String, dynamic>>> fetchTournamentTeams(String tournamentId);

  Future<String> insertTournamentMatch({
    required String tournamentId,
    required String homeTeamId,
    required String awayTeamId,
    DateTime? matchDate,
    String? venue,
  });

  Future<Map<String, dynamic>?> fetchTournamentById(String tournamentId);

  Future<void> insertTournamentJoinRequest({
    required String tournamentId,
    required String teamId,
  });
}
