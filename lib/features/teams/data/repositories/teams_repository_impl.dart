import 'dart:typed_data';

import '../models/app_team.dart';
import '../models/team_invite.dart';
import '../models/team_join_request.dart';
import '../models/team_match_request.dart';
import '../models/team_stats.dart';
import '../services/team_service.dart';
import '../../domain/repositories/teams_repository.dart';
import '../datasources/teams_remote_datasource.dart';

class TeamsRepositoryImpl implements TeamsRepository {
  TeamsRepositoryImpl(this._remote, this._teams);

  final TeamsRemoteDataSource _remote;
  final TeamService _teams;

  @override
  Stream<AppTeam?> watchTeam(String teamId) {
    return _remote.watchTeamDocument(teamId).map((data) {
      if (data == null) {
        return null;
      }
      return AppTeam.fromRemoteMap(teamId, data);
    });
  }

  @override
  Stream<List<AppTeam>> watchTeamsOrderedByWins() {
    return _remote.watchTeamsOrderedByWins().map(
          (rows) => rows
              .map(
                (m) => AppTeam.fromRemoteMap(m['id'] as String, m),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<Map<String, TeamStats>> watchAllTeamStatsById() {
    return _remote.watchTeamStatsCollection().map((rows) {
      final map = <String, TeamStats>{};
      for (final row in rows) {
        final id = row['id'] as String;
        map[id] = TeamStats.fromFirestoreMap(id, row);
      }
      return map;
    });
  }

  @override
  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic = true,
    Uint8List? logoBytes,
  }) {
    return _teams.createTeam(
      name: name,
      description: description,
      city: city,
      isPublic: isPublic,
      logoBytes: logoBytes,
    );
  }

  @override
  Future<void> setViceCaptainMembership({
    required String teamId,
    required String memberId,
    required bool addAsVice,
  }) {
    return _teams.setViceCaptainMembership(
      teamId: teamId,
      memberId: memberId,
      addAsVice: addAsVice,
    );
  }

  @override
  Future<List<AppTeam>> fetchUserTeams(String userId) {
    return _teams.fetchUserTeams(userId);
  }

  @override
  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return _teams.watchUserTeams(userId);
  }

  @override
  Future<AppTeam?> getTeam(String teamId) {
    return _teams.getTeam(teamId);
  }

  @override
  Stream<List<TeamInvite>> watchInvites(String userId) {
    return _teams.watchInvites(userId);
  }

  @override
  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  }) {
    return _teams.respondToInvite(invite: invite, accept: accept);
  }

  @override
  Stream<List<TeamMatchRequest>> watchMatchRequests(String teamId) {
    return _teams.watchMatchRequests(teamId);
  }

  @override
  Stream<TeamJoinRequest?> watchMyJoinRequest(String teamId, String userId) {
    return _teams.watchMyJoinRequest(teamId, userId);
  }

  @override
  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId) {
    return _teams.watchJoinRequests(teamId);
  }

  @override
  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  }) {
    return _teams.requestToJoinTeam(teamId: teamId, teamName: teamName);
  }

  @override
  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  }) {
    return _teams.respondToJoinRequest(request: request, accept: accept);
  }

  @override
  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster = const [],
  }) {
    return _teams.respondToMatchRequest(
      request: request,
      accept: accept,
      confirmedRoster: confirmedRoster,
    );
  }

  @override
  Future<void> sendMatchRequest({
    required String teamId,
    required String opponentTeamId,
    required String opponentName,
    required String matchId,
    List<String> proposedRoster = const [],
  }) {
    return _teams.sendMatchRequest(
      teamId: teamId,
      opponentTeamId: opponentTeamId,
      opponentName: opponentName,
      matchId: matchId,
      proposedRoster: proposedRoster,
    );
  }

  @override
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) {
    return _teams.leaveTeam(teamId: teamId, userId: userId);
  }

  @override
  Future<List<AppTeam>> searchTeams(String query, {int limit = 10}) {
    return _teams.searchTeams(query, limit: limit);
  }

  @override
  Future<List<Map<String, dynamic>>> searchPlayers(String query, {int limit = 10}) {
    return _teams.searchPlayers(query, limit: limit);
  }

  @override
  Future<void> invitePlayers({
    required String teamId,
    required String teamName,
    required List<String> userIds,
  }) {
    return _teams.invitePlayers(
      teamId: teamId,
      teamName: teamName,
      userIds: userIds,
    );
  }
}
