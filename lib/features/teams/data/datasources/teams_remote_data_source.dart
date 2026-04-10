import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/team_invite.dart';
import 'package:flap_app/models/team_join_request.dart';
import 'package:flap_app/models/team_match_request.dart';

abstract class TeamsRemoteDataSource {
  Stream<List<AppTeam>> watchUserTeams(String userId);

  Future<List<AppTeam>> fetchUserTeams(String userId);

  Future<AppTeam?> fetchTeam(String teamId);

  Stream<AppTeam?> watchTeam(String teamId);

  Stream<List<AppTeam>> watchTeamsLeaderboard();

  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic,
  });

  Future<void> updateTeamLogoUrl(String teamId, String logoUrl);

  Future<void> updateTeamInfo({
    required String teamId,
    String? name,
    String? description,
    String? city,
    bool? isPublic,
  });

  Future<void> insertTeamInvites(List<TeamInvite> invites);

  Stream<List<TeamInvite>> watchPendingInvitesForUser(String userId);

  Future<void> respondToInviteRpc({
    required String inviteId,
    required bool accept,
  });

  Stream<List<TeamJoinRequest>> watchPendingJoinRequestsForTeam(String teamId);

  Stream<TeamJoinRequest?> watchLatestJoinRequestForUserOnTeam({
    required String teamId,
    required String userId,
  });

  Future<String> insertJoinRequest(TeamJoinRequest request);

  Future<bool> hasPendingJoinRequest(String teamId, String userId);

  Future<void> respondToJoinRequestRpc({
    required String requestId,
    required bool accept,
  });

  Stream<List<TeamMatchRequest>> watchPendingMatchRequestsForTeam(String teamId);

  Future<void> insertMatchRequest(TeamMatchRequest request);

  Future<void> updateMatchRequestStatus({
    required String requestId,
    required bool accepted,
  });

  Future<List<AppTeam>> searchTeamsLocalFilter(String query, {int limit});

  Future<List<Map<String, dynamic>>> searchPlayersProfiles(
    String query, {
    int limit,
  });

  Future<void> leaveTeamRpc(String teamId);

  Future<void> insertTeamActivity({
    required String type,
    required String teamId,
    required String teamName,
    required String userId,
    required String userName,
  });

  Future<String?> fetchProfileDisplayName(String userId);

  /// Keys: `displayName`, `avatarUrl` (UI helpers).
  Future<Map<String, dynamic>?> fetchProfileForDisplay(String userId);

  Future<void> addViceCaptain(String teamId, String userId);

  Future<void> removeViceCaptain(String teamId, String userId);

  Future<void> applyStandingsAfterTeamMatch({
    required Match match,
    required int teamAScore,
    required int teamBScore,
    required Map<String, int> goalsByPlayer,
  });
}
