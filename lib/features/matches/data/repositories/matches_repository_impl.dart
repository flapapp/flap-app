import '../../../teams/data/models/app_team.dart';
import '../models/match.dart' as app_match;
import '../../../../services/match_service.dart';
import '../../domain/repositories/matches_repository.dart';
import '../datasources/matches_read_remote_datasource.dart';

class MatchesRepositoryImpl implements MatchesRepository {
  MatchesRepositoryImpl(this._remote, this._matches);

  final MatchesReadRemoteDataSource _remote;
  final MatchService _matches;

  @override
  Future<app_match.Match?> fetchMatchById(String matchId) async {
    final snap = await _remote.getMatch(matchId);
    if (!snap.exists) return null;
    return app_match.Match.fromFirestore(snap);
  }

  @override
  Stream<List<app_match.Match>> getAvailableMatches() {
    return _matches.getAvailableMatches();
  }

  @override
  Stream<List<app_match.Match>> getUserMatches(String userId) {
    return _matches.getUserMatches(userId);
  }

  @override
  Future<String> createMatch(app_match.Match match) {
    return _matches.createMatch(match);
  }

  @override
  Future<bool> joinMatch(String matchId, String userId) {
    return _matches.joinMatch(matchId, userId);
  }

  @override
  Future<bool> leaveMatch(String matchId, String userId) {
    return _matches.leaveMatch(matchId, userId);
  }

  @override
  Future<bool> applyForMatch(String matchId, String userId) {
    return _matches.applyForMatch(matchId, userId);
  }

  @override
  Future<bool> acceptApplication(String matchId, String userId) {
    return _matches.acceptApplication(matchId, userId);
  }

  @override
  Future<bool> rejectApplication(String matchId, String userId) {
    return _matches.rejectApplication(matchId, userId);
  }

  @override
  Future<bool> autoBalanceTeams(String matchId) {
    return _matches.autoBalanceTeams(matchId);
  }

  @override
  Future<bool> updateTeamsFlexible(String matchId, List<List<String>> teams) {
    return _matches.updateTeamsFlexible(matchId, teams);
  }

  @override
  Future<void> ensureFixtures(String matchId) {
    return _matches.ensureFixtures(matchId);
  }

  @override
  Future<bool> startMatch(String matchId) {
    return _matches.startMatch(matchId);
  }

  @override
  Future<bool> finishMatch(
    String matchId,
    app_match.MatchResult result,
    int teamAScore,
    int teamBScore, {
    Map<String, int> goalsByPlayer = const {},
  }) {
    return _matches.finishMatch(
      matchId,
      result,
      teamAScore,
      teamBScore,
      goalsByPlayer: goalsByPlayer,
    );
  }

  @override
  Future<bool> saveMultiTeamResults(
    String matchId,
    List<Map<String, int>> stats,
  ) {
    return _matches.saveMultiTeamResults(matchId, stats);
  }

  @override
  Future<bool> cancelMatch(String matchId) {
    return _matches.cancelMatch(matchId);
  }

  @override
  Future<bool> deleteMatch(String matchId) {
    return _matches.deleteMatch(matchId);
  }

  @override
  Future<void> setTeamRoster({
    required String matchId,
    required String teamKey,
    required AppTeam team,
    required List<String> playerIds,
  }) {
    return _matches.setTeamRoster(
      matchId: matchId,
      teamKey: teamKey,
      team: team,
      playerIds: playerIds,
    );
  }

  @override
  Future<void> respondToRosterInvite({
    required String matchId,
    required String teamKey,
    required bool accept,
  }) {
    return _matches.respondToRosterInvite(
      matchId: matchId,
      teamKey: teamKey,
      accept: accept,
    );
  }

  @override
  Future<void> updateCoverPhoto({
    required String matchId,
    required String photoUrl,
  }) {
    return _matches.updateCoverPhoto(matchId: matchId, photoUrl: photoUrl);
  }
}
