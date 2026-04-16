import '../entities/tournament_detail.dart';
import '../entities/tournament_match.dart';
import '../entities/tournament_summary.dart';
import '../entities/tournament_team_entry.dart';

abstract class TournamentsRepository {
  Future<List<TournamentSummary>> listTournaments();

  /// Tournaments that have not ended (excludes completed/cancelled and past [end_date]).
  Future<List<TournamentSummary>> listOngoingTournaments();

  Future<TournamentDetail?> getTournament(String tournamentId);

  Future<void> requestToJoinTournament({
    required String tournamentId,
    required String teamId,
  });

  Future<String> createTournament({
    required String name,
    required String type,
    int? maxTeams,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? rules,
  });

  Future<List<TournamentMatch>> listMatches(String tournamentId);

  Future<List<TournamentTeamEntry>> listTournamentTeams(String tournamentId);

  Future<String> createTournamentMatch({
    required String tournamentId,
    required String homeTeamId,
    required String awayTeamId,
    DateTime? matchDate,
    String? venue,
  });
}
