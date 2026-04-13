import 'dart:typed_data';

import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/team_invite.dart';
import 'package:flap_app/models/team_join_request.dart';
import 'package:flap_app/models/team_match_request.dart';

abstract class TeamsRepository {
  Stream<List<AppTeam>> watchUserTeams(String userId);

  Future<List<AppTeam>> fetchUserTeams(String userId);

  Future<AppTeam?> getTeam(String teamId);

  Stream<AppTeam?> watchTeam(String teamId);

  Stream<List<AppTeam>> watchTeamsLeaderboard();

  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic,
    Uint8List? logoBytes,
  });

  Future<void> updateTeamInfo({
    required String teamId,
    String? name,
    String? description,
    String? city,
    bool? isPublic,
  });

  Future<void> invitePlayers({
    required String teamId,
    required String teamName,
    required List<String> userIds,
  });

  Stream<List<TeamInvite>> watchInvites(String userId);

  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  });

  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId);

  Stream<TeamJoinRequest?> watchMyJoinRequest(String teamId, String userId);

  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  });

  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  });

  Stream<List<TeamMatchRequest>> watchMatchRequests(String teamId);

  Future<void> sendMatchRequest({
    required String teamId,
    required String opponentTeamId,
    required String opponentName,
    required String matchId,
    List<String> proposedRoster,
  });

  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster,
  });

  Future<List<AppTeam>> searchTeams(String query, {int limit});

  Future<List<Map<String, dynamic>>> searchPlayers(
    String query, {
    int limit,
    List<String>? profilePositionsAnyOf,
  });

  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  });

  Future<Map<String, dynamic>?> fetchProfileForDisplay(String userId);

  Future<void> promoteViceCaptain(String teamId, String memberId);

  Future<void> demoteViceCaptain(String teamId, String memberId);

  /// Updates two club rows after a team-vs-team match finishes (Supabase RPC).
  Future<void> applyStandingsAfterTeamMatch(
    Match match,
    int teamAScore,
    int teamBScore,
    Map<String, int> goalsByPlayer,
  );
}
