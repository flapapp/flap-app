import 'package:flutter/material.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/app_team.dart';

/// Matches lifecycle + fixtures (Supabase `matches`, `match_fixtures`).
/// Team standings for linked [AppTeam] rows use [TeamsRepository] (Supabase RPC).
abstract class MatchesRepository {
  Stream<List<Match>> getAvailableMatches();

  Stream<List<Match>> getUserMatches(String userId);

  Future<String> createMatch(Match match);

  Future<bool> joinMatch(String matchId, String userId);

  Future<bool> leaveMatch(String matchId, String userId);

  Future<bool> applyForMatch(String matchId, String userId);

  Future<bool> acceptApplication(String matchId, String userId);

  Future<bool> rejectApplication(String matchId, String userId);

  Stream<List<String>> getMatchApplications(String matchId);

  Future<bool> autoBalanceTeams(String matchId);

  Future<bool> updateTeams(
    String matchId,
    List<String> teamAPlayers,
    List<String> teamBPlayers,
  );

  Future<bool> updateTeamsFlexible(String matchId, List<List<String>> teams);

  Future<List<Map<String, dynamic>>> getFixtures(String matchId);

  Future<bool> finishGame(
    String matchId,
    String fixtureId,
    int scoreA,
    int scoreB,
  );

  Future<void> promptFinishGame(
    BuildContext context,
    String matchId,
    int fixtureIndex,
    String aName,
    String bName,
  );

  Future<void> ensureFixtures(String matchId);

  Future<bool> startMatch(String matchId);

  Future<bool> finishMatch(
    String matchId,
    MatchResult result,
    int teamAScore,
    int teamBScore, {
    Map<String, int> goalsByPlayer,
  });

  Stream<List<Match>> getMatchesForRating(String userId);

  Future<bool> cancelMatch(String matchId);

  Future<bool> deleteMatch(String matchId);

  Future<bool> saveMultiTeamResults(
    String matchId,
    List<Map<String, int>> stats,
  );

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

  Future<Match?> fetchMatch(String matchId);

  Future<void> saveMatch(Match match);

  Stream<Match?> watchMatch(String matchId);
}
