import '../../../../models/app_team.dart';
import '../../../../models/match.dart' as app_match;

/// Match lifecycle, queries, and organizer/player actions (domain).
abstract class MatchesRepository {
  Future<app_match.Match?> fetchMatchById(String matchId);

  Stream<List<app_match.Match>> getAvailableMatches();

  Stream<List<app_match.Match>> getUserMatches(String userId);

  Future<String> createMatch(app_match.Match match);

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
