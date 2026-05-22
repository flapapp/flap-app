import '../../../teams/data/models/app_team.dart';
import '../../data/models/match.dart' as app_match;

/// Match lifecycle, queries, and organizer/player actions (domain).
abstract class MatchesRepository {
  Future<app_match.Match?> fetchMatchById(String matchId);

  Future<List<app_match.Match>> fetchAvailableMatches();

  Future<List<app_match.Match>> fetchUserMatches(String userId);

  Future<String> createMatch(app_match.Match match);

  /// Atomic team-match creation via the SECURITY DEFINER RPC
  /// `public.create_team_match`. Use for any team match: it inserts the
  /// matches row, host slot, host roster, and team_match_requests row
  /// transactionally. Either all rows commit or none — no orphan matches.
  Future<String> createTeamMatch({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required String location,
    required String city,
    double? latitude,
    double? longitude,
    required int maxPlayers,
    required double cost,
    required app_match.MatchLevel level,
    required bool isPrivate,
    required String hostTeamId,
    List<String> hostRoster = const <String>[],
    String? opponentTeamId,
    List<String> opponentProposedRoster = const <String>[],
  });

  Future<bool> joinMatch(String matchId, String userId);

  Future<bool> leaveMatch(String matchId, String userId);

  Future<bool> applyForMatch(String matchId, String userId);

  Future<bool> acceptApplication(String matchId, String userId);

  Future<bool> rejectApplication(String matchId, String userId);

  Future<bool> autoBalanceTeams(String matchId);

  Future<bool> updateTeamsFlexible(String matchId, List<List<String>> teams);

  Future<void> ensureFixtures(String matchId);

  Future<bool> startMatch(String matchId);

  Future<bool> finishMatch(
    String matchId,
    app_match.MatchResult result,
    int teamAScore,
    int teamBScore, {
    Map<String, int> goalsByPlayer,
  });

  Future<bool> saveMultiTeamResults(
    String matchId,
    List<Map<String, int>> stats,
  );

  Future<bool> cancelMatch(String matchId);

  Future<bool> deleteMatch(String matchId);

  Future<void> setTeamRoster({
    required String matchId,
    required String teamKey,
    required AppTeam team,
    required List<String> playerIds,
  });

  Future<void> respondToRosterInvite({
    required String matchId,
    required String teamKey,
    required bool accept,
  });

  Future<void> updateCoverPhoto({
    required String matchId,
    required String photoUrl,
  });
}
