import 'dart:typed_data';

import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/core/storage/supabase_team_logo_storage.dart';
import 'package:flap_app/features/matches/domain/repositories/matches_repository.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/notification.dart';
import 'package:flap_app/models/team_invite.dart';
import 'package:flap_app/models/team_join_request.dart';
import 'package:flap_app/models/team_match_request.dart';
import 'package:flap_app/utils/i18n.dart';

import '../../domain/repositories/teams_repository.dart';
import '../datasources/teams_remote_data_source.dart';

class TeamsRepositoryImpl implements TeamsRepository {
  TeamsRepositoryImpl(
    this._remote,
    MatchesRepository Function() matchesFn,
  ) : _matchesFn = matchesFn;

  final TeamsRemoteDataSource _remote;
  final MatchesRepository Function() _matchesFn;

  MatchesRepository get _matches => _matchesFn();

  @override
  Stream<List<AppTeam>> watchUserTeams(String userId) =>
      _remote.watchUserTeams(userId);

  @override
  Future<List<AppTeam>> fetchUserTeams(String userId) =>
      _remote.fetchUserTeams(userId);

  @override
  Future<AppTeam?> getTeam(String teamId) => _remote.fetchTeam(teamId);

  @override
  Stream<AppTeam?> watchTeam(String teamId) => _remote.watchTeam(teamId);

  @override
  Stream<List<AppTeam>> watchTeamsLeaderboard() =>
      _remote.watchTeamsLeaderboard();

  @override
  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic = true,
    Uint8List? logoBytes,
  }) async {
    try {
      final id = await _remote.createTeam(
        name: name,
        description: description,
        city: city,
        isPublic: isPublic,
      );
      if (logoBytes != null) {
        final url = await SupabaseTeamLogoStorage.uploadTeamLogo(
          teamId: id,
          bytes: logoBytes,
        );
        await _remote.updateTeamLogoUrl(id, url);
      }
      return id;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('max_teams')) {
        throw Exception(
          I18n.inline(
            'Максимум 3 команди на гравця',
            'Maximum of 3 teams per player',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> updateTeamInfo({
    required String teamId,
    String? name,
    String? description,
    String? city,
    bool? isPublic,
  }) =>
      _remote.updateTeamInfo(
        teamId: teamId,
        name: name,
        description: description,
        city: city,
        isPublic: isPublic,
      );

  @override
  Future<void> invitePlayers({
    required String teamId,
    required String teamName,
    required List<String> userIds,
  }) async {
    final user = AppAuthContext.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final invites = userIds
        .map(
          (targetId) => TeamInvite(
            id: '',
            teamId: teamId,
            teamName: teamName,
            userId: targetId,
            invitedBy: user.id,
            status: TeamInviteStatus.pending,
            createdAt: now,
          ),
        )
        .toList();
    await _remote.insertTeamInvites(invites);
    final notifier = NotificationService();
    for (final uid in userIds) {
      await notifier.sendNotification(
        AppNotification.teamInvite(
          userId: uid,
          teamId: teamId,
          teamName: teamName,
        ),
      );
    }
  }

  @override
  Stream<List<TeamInvite>> watchInvites(String userId) =>
      _remote.watchPendingInvitesForUser(userId);

  @override
  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  }) async {
    if (accept) {
      final userTeams = await fetchUserTeams(invite.userId);
      if (userTeams.length >= 3) {
        throw Exception(
          I18n.inline(
            'Максимум 3 команди на гравця',
            'Maximum of 3 teams per player',
          ),
        );
      }
    }
    try {
      await _remote.respondToInviteRpc(inviteId: invite.id, accept: accept);
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('max_teams')) {
        throw Exception(
          I18n.inline(
            'Максимум 3 команди на гравця',
            'Maximum of 3 teams per player',
          ),
        );
      }
      rethrow;
    }
    if (accept) {
      final userName =
          await _remote.fetchProfileDisplayName(invite.userId) ?? 'Player';
      await _remote.insertTeamActivity(
        type: 'joined_team',
        teamId: invite.teamId,
        teamName: invite.teamName,
        userId: invite.userId,
        userName: userName,
      );
    }
  }

  @override
  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId) =>
      _remote.watchPendingJoinRequestsForTeam(teamId);

  @override
  Stream<TeamJoinRequest?> watchMyJoinRequest(String teamId, String userId) =>
      _remote.watchLatestJoinRequestForUserOnTeam(
        teamId: teamId,
        userId: userId,
      );

  @override
  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  }) async {
    final user = AppAuthContext.currentUser;
    if (user == null) {
      throw Exception(
        I18n.inline('Потрібна авторизація', 'Sign-in required'),
      );
    }
    final team = await _remote.fetchTeam(teamId);
    if (team == null) {
      throw Exception(
        I18n.inline('Команду не знайдено', 'Team not found'),
      );
    }
    if (team.memberIds.contains(user.id)) {
      throw Exception(
        I18n.inline('Ви вже у цій команді', 'You are already on this team'),
      );
    }
    if (await _remote.hasPendingJoinRequest(teamId, user.id)) {
      throw Exception(
        I18n.inline('Запит вже надіслано', 'Request already sent'),
      );
    }
    final requesterName = user.displayName ??
        user.email?.split('@').first ??
        'Player';
    final req = TeamJoinRequest(
      id: '',
      teamId: teamId,
      teamName: teamName,
      userId: user.id,
      userName: requesterName,
      status: TeamJoinRequestStatus.pending,
      createdAt: DateTime.now(),
    );
    String requestId;
    try {
      requestId = await _remote.insertJoinRequest(req);
    } catch (_) {
      rethrow;
    }
    try {
      final captainId = team.captainId;
      final viceIds = team.viceCaptainIds;
      final recipients = {
        if (captainId.isNotEmpty) captainId,
        ...viceIds.where((id) => id.isNotEmpty),
      }..remove(user.id);
      if (recipients.isNotEmpty) {
        final notifier = NotificationService();
        final resolvedTeamName =
            teamName.isNotEmpty ? teamName : team.name;
        for (final target in recipients) {
          await notifier.sendTeamJoinRequestNotification(
            toUserId: target,
            teamId: teamId,
            teamName: resolvedTeamName,
            requesterName: requesterName,
            requestId: requestId,
          );
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  }) async {
    final currentUser = AppAuthContext.currentUser;
    if (currentUser == null) return;
    final team = await _remote.fetchTeam(request.teamId);
    if (team == null) {
      throw Exception(
        I18n.inline('Команду не знайдено', 'Team not found'),
      );
    }
    final canManage = team.captainId == currentUser.id ||
        team.viceCaptainIds.contains(currentUser.id);
    if (!canManage) {
      throw Exception(
        I18n.inline('Недостатньо прав', 'Insufficient permissions'),
      );
    }
    try {
      await _remote.respondToJoinRequestRpc(
        requestId: request.id,
        accept: accept,
      );
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('max_teams')) {
        throw Exception(
          I18n.inline(
            'Максимум 3 команди на гравця',
            'Maximum of 3 teams per player',
          ),
        );
      }
      rethrow;
    }
    if (accept) {
      await _remote.insertTeamActivity(
        type: 'joined_team',
        teamId: request.teamId,
        teamName: request.teamName,
        userId: request.userId,
        userName: request.userName,
      );
    }
  }

  @override
  Stream<List<TeamMatchRequest>> watchMatchRequests(String teamId) =>
      _remote.watchPendingMatchRequestsForTeam(teamId);

  @override
  Future<void> sendMatchRequest({
    required String teamId,
    required String opponentTeamId,
    required String opponentName,
    required String matchId,
    List<String> proposedRoster = const [],
  }) async {
    final user = AppAuthContext.currentUser;
    if (user == null) return;
    final req = TeamMatchRequest(
      id: '',
      matchId: matchId,
      teamId: teamId,
      opponentTeamId: opponentTeamId,
      opponentName: opponentName,
      createdBy: user.id,
      status: TeamMatchRequestStatus.pending,
      createdAt: DateTime.now(),
      proposedRoster: proposedRoster,
    );
    await _remote.insertMatchRequest(req);
    try {
      final team = await _remote.fetchTeam(teamId);
      if (team == null) return;
      final captainId = team.captainId;
      final viceIds = team.viceCaptainIds;
      final recipients = <String>{
        if (captainId.isNotEmpty) captainId,
        ...viceIds,
      };
      final notifier = NotificationService();
      for (final recipient in recipients) {
        await notifier.sendNotification(
          AppNotification.teamMatchRequest(
            userId: recipient,
            opponentTeamName: opponentName,
            matchId: matchId,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster = const [],
  }) async {
    await _remote.updateMatchRequestStatus(
      requestId: request.id,
      accepted: accept,
    );
    final match = await _matches.fetchMatch(request.matchId);
    if (match == null) return;
    if (!accept) {
      final isHost = match.teamAId == request.teamId;
      await _matches.saveMatch(
        match.copyWith(
          teamAStatus: isHost ? 'declined' : match.teamAStatus,
          teamBStatus: isHost ? match.teamBStatus : 'declined',
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    final teamRow = await _remote.fetchTeam(request.teamId);
    final teamName = teamRow?.name ?? 'Team';
    final roster = List<String>.from(confirmedRoster);
    final assignedTeamKey =
        match.teamAId == request.teamId ? 'teamA' : 'teamB';
    final rosterStatus = {for (final uid in roster) uid: 'pending'};
    final newParticipants =
        {...match.participants.toSet(), ...roster}.toList();
    final rosters = Map<String, List<String>>.from(match.teamRosters);
    rosters[assignedTeamKey] = roster;
    final rosterStatuses =
        Map<String, Map<String, String>>.from(match.teamRosterStatus);
    rosterStatuses[assignedTeamKey] = rosterStatus;
    final sideTeam = Team(
      name: teamName,
      playerIds: List<String>.from(roster),
      averageRating: 0,
    );
    await _matches.saveMatch(
      match.copyWith(
        participants: newParticipants,
        teamRosters: rosters,
        teamRosterStatus: rosterStatuses,
        teamAStatus:
            assignedTeamKey == 'teamA' ? 'pending' : match.teamAStatus,
        teamBStatus:
            assignedTeamKey == 'teamB' ? 'pending' : match.teamBStatus,
        teamAId: assignedTeamKey == 'teamA' ? request.teamId : match.teamAId,
        teamBId: assignedTeamKey == 'teamB' ? request.teamId : match.teamBId,
        teamA: assignedTeamKey == 'teamA' ? sideTeam : match.teamA,
        teamB: assignedTeamKey == 'teamB' ? sideTeam : match.teamB,
        updatedAt: DateTime.now(),
      ),
    );
    if (roster.isNotEmpty) {
      final notifier = NotificationService();
      for (final playerId in roster) {
        await notifier.sendTeamRosterInvite(
          toUserId: playerId,
          matchId: request.matchId,
          teamName: teamName,
          teamKey: assignedTeamKey,
        );
      }
    }
  }

  @override
  Future<List<AppTeam>> searchTeams(String query, {int limit = 10}) =>
      _remote.searchTeamsLocalFilter(query, limit: limit);

  @override
  Future<List<Map<String, dynamic>>> searchPlayers(String query,
          {int limit = 10}) =>
      _remote.searchPlayersProfiles(query, limit: limit);

  @override
  Future<Map<String, dynamic>?> fetchProfileForDisplay(String userId) =>
      _remote.fetchProfileForDisplay(userId);

  @override
  Future<void> promoteViceCaptain(String teamId, String memberId) =>
      _remote.addViceCaptain(teamId, memberId);

  @override
  Future<void> demoteViceCaptain(String teamId, String memberId) =>
      _remote.removeViceCaptain(teamId, memberId);

  @override
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    final team = await _remote.fetchTeam(teamId);
    final teamNameForFeed = team?.name ?? 'Team';
    try {
      await _remote.leaveTeamRpc(teamId);
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('team_not_found')) {
        throw Exception(
          I18n.inline('Команду не знайдено', 'Team not found'),
        );
      }
      if (s.contains('not_member')) {
        throw Exception(
          I18n.inline(
            'Ви не є учасником цієї команди',
            'You are not a member of this team',
          ),
        );
      }
      if (s.contains('last_member')) {
        throw Exception(
          I18n.inline(
            'Ви останній учасник. Видаліть команду або передайте капітанство.',
            'You are the last member. Delete the team or transfer captain role.',
          ),
        );
      }
      if (s.contains('no_successor')) {
        throw Exception(
          I18n.inline(
            'Не вдалося визначити нового капітана',
            'Failed to determine next captain',
          ),
        );
      }
      rethrow;
    }
    final userName =
        await _remote.fetchProfileDisplayName(userId) ?? 'Player';
    await _remote.insertTeamActivity(
      type: 'left_team',
      teamId: teamId,
      teamName: teamNameForFeed,
      userId: userId,
      userName: userName,
    );
  }

  @override
  Future<void> applyStandingsAfterTeamMatch(
    Match match,
    int teamAScore,
    int teamBScore,
    Map<String, int> goalsByPlayer,
  ) =>
      _remote.applyStandingsAfterTeamMatch(
        match: match,
        teamAScore: teamAScore,
        teamBScore: teamBScore,
        goalsByPlayer: goalsByPlayer,
      );
}
