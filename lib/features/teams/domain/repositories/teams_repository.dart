import 'dart:typed_data';

import '../../data/models/app_team.dart';
import '../../data/models/team_invite.dart';
import '../../data/models/team_join_request.dart';
import '../../data/models/team_match_request.dart';
import '../../data/models/team_stats.dart';

/// Teams: reads (leaderboard, stats), lifecycle (create), and operations (join, invites, match requests).
abstract class TeamsRepository {
  /// Emits [null] while loading or if the document is missing.
  Stream<AppTeam?> watchTeam(String teamId);

  Stream<List<AppTeam>> watchTeamsOrderedByWins();

  /// Latest `teamStats/{id}` documents keyed by team id.
  Stream<Map<String, TeamStats>> watchAllTeamStatsById();

  Future<List<AppTeam>> fetchUserTeams(String userId);

  Stream<List<AppTeam>> watchUserTeams(String userId);

  Future<AppTeam?> getTeam(String teamId);

  Stream<List<TeamInvite>> watchInvites(String userId);

  /// Pending invitations a team has sent to players, for team officers.
  Stream<List<TeamInvite>> watchSentInvites(String teamId);

  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  });

  /// Retract a pending invitation the team sent (officer-only).
  Future<void> cancelInvite({required String inviteId});

  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic = true,
    Uint8List? logoBytes,
  });

  Future<void> setViceCaptainMembership({
    required String teamId,
    required String memberId,
    required bool addAsVice,
  });

  Stream<List<TeamMatchRequest>> watchIncomingTeamMatchInvites(String teamId);

  Stream<List<TeamMatchRequest>> watchOutgoingTeamMatchRequests(String teamId);

  Future<List<AppTeam>> fetchTeamsWhereUserIsOfficer(String userId);

  Stream<TeamJoinRequest?> watchMyJoinRequest(String teamId, String userId);

  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId);

  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  });

  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  });

  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster = const [],
  });

  /// Cancel an outgoing team match request (requesting team officer or
  /// match organizer).
  Future<void> cancelMatchRequest({required String requestId});

  Future<void> sendMatchRequest({
    required String teamId,
    required String opponentTeamId,
    required String opponentName,
    required String matchId,
    List<String> proposedRoster = const [],
  });

  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  });

  Future<List<AppTeam>> searchTeams(String query, {int limit = 10});

  Future<List<Map<String, dynamic>>> searchPlayers(String query, {int limit = 10});

  Future<void> invitePlayers({
    required String teamId,
    required String teamName,
    required List<String> userIds,
  });
}
