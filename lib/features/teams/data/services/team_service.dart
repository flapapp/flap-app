import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../core/supabase/guard_supabase_realtime_stream.dart';
import '../../../../utils/city_catalog.dart';
import '../../data/models/app_team.dart';
import '../../data/models/team_invite.dart';
import '../../data/models/team_join_request.dart';
import '../../data/models/team_match_request.dart';
import 'package:flap_app/core/auth/app_auth.dart';

/// Builds the parameter map for [TeamService.respondToMatchRequest] when the
/// caller is accepting. Pure function so callers and tests share one source
/// of truth for the Supabase RPC contract.
@visibleForTesting
Map<String, dynamic> buildAcceptTeamMatchRpcParams({
  required String requestId,
  required List<String> confirmedRoster,
}) {
  final cleaned = <String>{};
  for (final id in confirmedRoster) {
    final v = id.trim();
    if (v.isNotEmpty) cleaned.add(v);
  }
  return <String, dynamic>{
    'p_request_id': requestId,
    if (cleaned.isNotEmpty) 'p_roster': cleaned.toList(growable: false),
  };
}

@visibleForTesting
Map<String, dynamic> buildDeclineTeamMatchRpcParams({
  required String requestId,
}) {
  return <String, dynamic>{'p_request_id': requestId};
}

@visibleForTesting
Map<String, dynamic> buildCancelTeamMatchRpcParams({
  required String requestId,
}) {
  return <String, dynamic>{'p_request_id': requestId};
}

class TeamService {
  TeamService._();
  static final TeamService _instance = TeamService._();
  factory TeamService() => _instance;

  SupabaseClient get _sb => Supabase.instance.client;

  Future<AppTeam?> _loadTeam(String teamId) async {
    final teamRow = await _sb
        .from('teams')
        .select()
        .eq('id', teamId)
        .maybeSingle();
    if (teamRow == null) return null;

    final members = await _sb
        .from('team_members')
        .select('user_id, role')
        .eq('team_id', teamId);

    String captainId = '';
    final viceCaptainIds = <String>[];
    final memberIds = <String>[];
    for (final raw in members as List<dynamic>) {
      final m = raw as Map<String, dynamic>;
      final uid = (m['user_id'] ?? '').toString();
      if (uid.isEmpty) continue;
      memberIds.add(uid);
      final role = (m['role'] ?? 'member').toString();
      if (role == 'captain') {
        captainId = uid;
      } else if (role == 'vice_captain') {
        viceCaptainIds.add(uid);
      }
    }

    return AppTeam.fromRemoteMap(teamId, <String, dynamic>{
      'name': teamRow['name'],
      'description': teamRow['description'] ?? '',
      'captainId': captainId,
      'viceCaptainIds': viceCaptainIds,
      'memberIds': memberIds,
      'isPublic': teamRow['is_public'] ?? true,
      'logoUrl': teamRow['logo_url'],
      'city': teamRow['city'],
      'createdAt': teamRow['created_at'],
      'updatedAt': teamRow['updated_at'],
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'goalsFor': 0,
      'goalsAgainst': 0,
      'playerGoals': const <String, int>{},
      'recentMatches': const <Map<String, dynamic>>[],
    });
  }

  /// Single-emission stream of the user's teams. Membership only changes
  /// through actions the app already refreshes after (create / join / leave /
  /// invite response), so this is fetched once per subscription.
  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return Stream.fromFuture(fetchUserTeams(userId));
  }

  Future<List<AppTeam>> fetchUserTeams(String userId) async {
    final rows = await _sb
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId);
    final ids = (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['team_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final teams = <AppTeam>[];
    for (final id in ids) {
      final t = await _loadTeam(id);
      if (t != null) teams.add(t);
    }
    return teams;
  }

  Future<AppTeam?> getTeam(String teamId) async {
    return _loadTeam(teamId);
  }

  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic = true,
    Uint8List? logoBytes,
  }) async {
    final user = AppAuth.currentUser;
    if (user == null) {
      throw Exception(tr('team_error_not_signed_in'));
    }

    final existingMemberships = await _sb
        .from('team_members')
        .select('id')
        .eq('user_id', user.id);
    if ((existingMemberships as List<dynamic>).length >= 3) {
      throw Exception(tr('team_error_max_teams_three'));
    }

    final inserted = await _sb
        .from('teams')
        .insert(<String, dynamic>{
          'name': name,
          'description': description,
          'city': (city == null || city.isEmpty)
              ? city
              : (CityCatalog.toEnglishStorageKey(city) ?? city),
          'is_public': isPublic,
          'created_by': user.id,
        })
        .select('id')
        .single();
    final teamId = inserted['id'].toString();

    await _sb.from('team_members').insert(<String, dynamic>{
      'team_id': teamId,
      'user_id': user.id,
      'role': 'captain',
    });

    if (logoBytes != null) {
      final logoUrl = await _uploadTeamLogo(teamId, logoBytes);
      await _sb
          .from('teams')
          .update(<String, dynamic>{'logo_url': logoUrl})
          .eq('id', teamId);
    }

    return teamId;
  }

  Future<String> _uploadTeamLogo(String teamId, Uint8List bytes) async {
    final uid = AppAuth.currentUser?.id;
    if (uid == null) {
      throw Exception(tr('team_error_not_signed_in'));
    }
    final path = '$uid/$teamId-${DateTime.now().millisecondsSinceEpoch}.png';
    return SupabaseAppStorage.uploadPublicBytes(
      Supabase.instance.client,
      bucket: SupabaseAppStorage.teamLogos,
      path: path,
      bytes: bytes,
      contentType: 'image/png',
    );
  }

  Future<void> setViceCaptainMembership({
    required String teamId,
    required String memberId,
    required bool addAsVice,
  }) async {
    if (addAsVice) {
      await _sb.from('team_members').upsert(<String, dynamic>{
        'team_id': teamId,
        'user_id': memberId,
        'role': 'vice_captain',
      }, onConflict: 'team_id,user_id');
    } else {
      await _sb
          .from('team_members')
          .update(<String, dynamic>{'role': 'member'})
          .eq('team_id', teamId)
          .eq('user_id', memberId)
          .eq('role', 'vice_captain');
    }
    await _notifyTeamRoleChanged(
      teamId: teamId,
      memberId: memberId,
      typeCode: addAsVice ? 'team_vice_added' : 'team_vice_removed',
    );
  }

  /// Notifies a member when their team role changes (promoted/demoted vice, or
  /// handed the captaincy). Uses the backend enqueue RPC (auth'd caller may
  /// target another user); a failed notification never fails the role change.
  Future<void> _notifyTeamRoleChanged({
    required String teamId,
    required String memberId,
    required String typeCode,
  }) async {
    try {
      final teamRow = await _sb
          .from('teams')
          .select('name')
          .eq('id', teamId)
          .maybeSingle();
      final teamName = (teamRow?['name'] ?? tr('team')).toString();

      final String title;
      final String message;
      switch (typeCode) {
        case 'team_vice_added':
          title = tr('notif_team_vice_added_title');
          message =
              tr('notif_team_vice_added_body', namedArgs: {'teamName': teamName});
          break;
        case 'team_vice_removed':
          title = tr('notif_team_vice_removed_title');
          message = tr('notif_team_vice_removed_body',
              namedArgs: {'teamName': teamName});
          break;
        default: // team_new_captain
          title = tr('notif_team_new_captain_title');
          message = tr('notif_team_new_captain_body',
              namedArgs: {'teamName': teamName});
      }

      await _sb.rpc(
        'enqueue_notification_backend',
        params: <String, dynamic>{
          'p_target_user_id': memberId,
          'p_type_code': 'team_role_changed',
          'p_title': title,
          'p_message': message,
          'p_data': <String, dynamic>{'teamId': teamId, 'teamName': teamName},
          'p_related_table': 'teams',
          'p_related_record_id': teamId,
          'p_action_url': '/teams',
          'p_idempotency_key':
              '$typeCode:$teamId:$memberId:${DateTime.now().toUtc().millisecondsSinceEpoch}',
        },
      );
    } catch (_) {
      // A failed notification must not fail the role change.
    }
  }

  Future<void> updateTeamInfo({
    required String teamId,
    String? name,
    String? description,
    String? city,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (city != null) {
      updates['city'] = city.isEmpty
          ? city
          : (CityCatalog.toEnglishStorageKey(city) ?? city);
    }
    if (isPublic != null) updates['is_public'] = isPublic;
    if (updates.isNotEmpty) {
      await _sb.from('teams').update(updates).eq('id', teamId);
    }
  }

  Future<void> invitePlayers({
    required String teamId,
    required String teamName,
    required List<String> userIds,
  }) async {
    final user = AppAuth.currentUser;
    if (user == null) return;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final targetId in userIds) {
      await _sb.from('team_invites').insert(<String, dynamic>{
        'team_id': teamId,
        'user_id': targetId,
        'invited_by': user.id,
        'status': 'pending',
        'created_at': now,
      });
    }
    // Backend trigger handles team invitation notifications.
  }

  /// Single-emission stream of the pending invitations sent to [userId].
  /// Notifications already tell the user an invite arrived; the list itself is
  /// fetched once per subscription and re-read on refresh.
  Stream<List<TeamInvite>> watchInvites(String userId) {
    return Stream.fromFuture(fetchInvites(userId));
  }

  Future<List<TeamInvite>> fetchInvites(String userId) async {
    final rows = await _sb
        .from('team_invites')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending');
    final invites = (rows as List<dynamic>).cast<Map<String, dynamic>>();
    final teamNames = await _fetchTeamNames(
      invites.map((row) => (row['team_id'] ?? '').toString()),
    );
    return invites.map((row) {
      final teamId = (row['team_id'] ?? '').toString();
      return TeamInvite.fromJson(<String, dynamic>{
        'id': row['id'],
        'teamId': teamId,
        'teamName': teamNames[teamId] ?? '',
        'userId': row['user_id'],
        'invitedBy': row['invited_by'],
        'status': row['status'],
        'createdAt': row['created_at'],
      });
    }).toList();
  }

  /// Batch team-name lookup, replacing the per-row query these mappers used to
  /// run for every invite / join request.
  Future<Map<String, String>> _fetchTeamNames(Iterable<String> teamIds) async {
    final ids = teamIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _sb.from('teams').select('id,name').inFilter('id', ids);
    return <String, String>{
      for (final raw in rows as List<dynamic>)
        (raw as Map<String, dynamic>)['id'].toString(): (raw['name'] ?? '')
            .toString(),
    };
  }

  /// The pending invitations a team has sent to players, for team officers to
  /// review on the team detail page. RLS restricts reads to involved users
  /// (invitee, inviter, or a team officer).
  ///
  /// Single-emission: the officer sending or retracting an invite refreshes
  /// this list directly, so it does not need a live subscription.
  Stream<List<TeamInvite>> watchSentInvites(String teamId) {
    return Stream.fromFuture(fetchSentInvites(teamId));
  }

  Future<List<TeamInvite>> fetchSentInvites(String teamId) async {
    final rows = await _sb
        .from('team_invites')
        .select()
        .eq('team_id', teamId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((raw) {
          final row = raw as Map<String, dynamic>;
          return TeamInvite.fromJson(<String, dynamic>{
            'id': row['id'],
            'teamId': row['team_id'],
            'teamName': '',
            'userId': row['user_id'],
            'invitedBy': row['invited_by'],
            'status': row['status'],
            'createdAt': row['created_at'],
          });
        })
        .toList(growable: false);
  }

  /// Retracts a pending invitation. Officer-only via RLS.
  Future<void> cancelInvite({required String inviteId}) async {
    await _sb
        .from('team_invites')
        .update(<String, dynamic>{
          'status': 'cancelled',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', inviteId);
  }

  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  }) async {
    final userTeams = await fetchUserTeams(invite.userId);
    if (accept && userTeams.length >= 3) {
      throw Exception(tr('team_error_max_teams_three'));
    }
    await _sb
        .from('team_invites')
        .update(<String, dynamic>{
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', invite.id);

    if (accept) {
      await _sb.from('team_members').upsert(<String, dynamic>{
        'team_id': invite.teamId,
        'user_id': invite.userId,
        'role': 'member',
      }, onConflict: 'team_id,user_id');
    }

    if (accept) {
      final userRow = await _sb
          .from('profiles')
          .select('display_name, nickname, first_name, last_name')
          .eq('id', invite.userId)
          .maybeSingle();
      final userName =
          (userRow?['display_name'] ??
                  userRow?['nickname'] ??
                  '${userRow?['first_name'] ?? ''} ${userRow?['last_name'] ?? ''}'
                      .trim() ??
                  tr('player'))
              .toString();
      await _publishTeamMovementNews(
        action: 'joined_team',
        teamId: invite.teamId,
        teamName: invite.teamName,
        userId: invite.userId,
        userName: userName,
      );
    }

    // Tell the inviter whether their invite was accepted or declined.
    await _notifyInviteOutcome(invite: invite, accept: accept);
  }

  /// Notifies the team officer who sent an invite of the invitee's response.
  Future<void> _notifyInviteOutcome({
    required TeamInvite invite,
    required bool accept,
  }) async {
    if (invite.invitedBy.isEmpty) return;
    try {
      final responderRow = await _sb
          .from('profiles')
          .select('display_name, nickname, first_name, last_name')
          .eq('id', invite.userId)
          .maybeSingle();
      final responderName = (responderRow?['display_name'] ??
              responderRow?['nickname'] ??
              '${responderRow?['first_name'] ?? ''} ${responderRow?['last_name'] ?? ''}'
                  .trim() ??
              tr('player'))
          .toString()
          .trim();
      final name = responderName.isEmpty ? tr('player') : responderName;

      await _sb.rpc(
        'enqueue_notification_backend',
        params: <String, dynamic>{
          'p_target_user_id': invite.invitedBy,
          'p_type_code':
              accept ? 'team_invite_accepted' : 'team_invite_declined',
          'p_title': accept
              ? tr('notif_team_invite_accepted_title')
              : tr('notif_team_invite_declined_title'),
          'p_message': accept
              ? tr('notif_team_invite_accepted_body',
                  namedArgs: {'name': name, 'teamName': invite.teamName})
              : tr('notif_team_invite_declined_body',
                  namedArgs: {'name': name, 'teamName': invite.teamName}),
          'p_data': <String, dynamic>{
            'teamId': invite.teamId,
            'teamName': invite.teamName,
          },
          'p_related_table': 'teams',
          'p_related_record_id': invite.teamId,
          'p_action_url': '/teams',
          'p_idempotency_key':
              'team_invite_${accept ? 'accepted' : 'declined'}:${invite.id}',
        },
      );
    } catch (_) {
      // A failed notification must not fail the response action.
    }
  }

  /// Single-emission stream of a team's pending join requests. Officers are
  /// notified when one arrives, and responding to one refreshes this list.
  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId) {
    return Stream.fromFuture(fetchJoinRequests(teamId));
  }

  Future<List<TeamJoinRequest>> fetchJoinRequests(String teamId) async {
    final rows = await _sb
        .from('team_join_requests')
        .select()
        .eq('team_id', teamId)
        .eq('status', 'pending');
    return _mapJoinRequests(rows as List<dynamic>);
  }

  /// Single-emission stream of the viewer's own join request for [teamId]
  /// (most recent first), used to show "request pending" on the team page.
  Stream<TeamJoinRequest?> watchMyJoinRequest(String teamId, String userId) {
    return Stream.fromFuture(fetchMyJoinRequest(teamId, userId));
  }

  Future<TeamJoinRequest?> fetchMyJoinRequest(
    String teamId,
    String userId,
  ) async {
    final rows = await _sb
        .from('team_join_requests')
        .select()
        .eq('team_id', teamId)
        .eq('user_id', userId);
    final mapped = await _mapJoinRequests(rows as List<dynamic>);
    if (mapped.isEmpty) return null;
    mapped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mapped.first;
  }

  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  }) async {
    final user = AppAuth.currentUser;
    if (user == null) {
      throw Exception(tr('team_error_auth_required'));
    }
    final team = await _loadTeam(teamId);
    if (team == null) {
      throw Exception(tr('team_error_team_not_found'));
    }
    if (team.memberIds.contains(user.id)) {
      throw Exception(tr('team_error_already_member'));
    }

    final pendingExisting = await _sb
        .from('team_join_requests')
        .select('id')
        .eq('team_id', teamId)
        .eq('user_id', user.id)
        .eq('status', 'pending');
    if ((pendingExisting as List).isNotEmpty) {
      throw Exception(tr('team_error_join_request_pending'));
    }

    final requesterName =
        (user.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (user.userMetadata!['full_name'] as String).trim()
        : (user.email?.split('@').first ?? tr('player'));
    await _sb
        .from('team_join_requests')
        .insert(<String, dynamic>{
          'team_id': teamId,
          'user_id': user.id,
          'status': 'pending',
          'message': requesterName,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    // Backend trigger handles team join request notifications.
  }

  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  }) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    final team = await _loadTeam(request.teamId);
    if (team == null) {
      throw Exception(tr('team_error_team_not_found'));
    }
    final captainId = team.captainId;
    final viceIds = team.viceCaptainIds;
    final canManage =
        captainId == currentUser.id || viceIds.contains(currentUser.id);
    if (!canManage) {
      throw Exception(tr('team_error_insufficient_permissions'));
    }

    await _sb
        .from('team_join_requests')
        .update({
          'status': accept ? 'accepted' : 'declined',
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', request.id);

    if (accept) {
      await _sb.from('team_members').upsert(<String, dynamic>{
        'team_id': request.teamId,
        'user_id': request.userId,
        'role': 'member',
      }, onConflict: 'team_id,user_id');
    }

    if (accept) {
      await _publishTeamMovementNews(
        action: 'joined_team',
        teamId: request.teamId,
        teamName: request.teamName,
        userId: request.userId,
        userName: request.userName,
      );
    }

    // Tell the requester the outcome of their join request.
    await _notifyJoinRequestOutcome(request: request, accept: accept);
  }

  /// Notifies the player who asked to join whether they were approved or not.
  /// Uses the backend enqueue RPC (auth'd caller may target another user), the
  /// same path badge endorsements use.
  Future<void> _notifyJoinRequestOutcome({
    required TeamJoinRequest request,
    required bool accept,
  }) async {
    try {
      await _sb.rpc(
        'enqueue_notification_backend',
        params: <String, dynamic>{
          'p_target_user_id': request.userId,
          'p_type_code': accept ? 'team_join_approved' : 'team_join_rejected',
          'p_title': accept
              ? tr('notif_team_join_approved_title')
              : tr('notif_team_join_rejected_title'),
          'p_message': accept
              ? tr('notif_team_join_approved_body',
                  namedArgs: {'teamName': request.teamName})
              : tr('notif_team_join_rejected_body',
                  namedArgs: {'teamName': request.teamName}),
          'p_data': <String, dynamic>{
            'teamId': request.teamId,
            'teamName': request.teamName,
          },
          'p_related_table': 'teams',
          'p_related_record_id': request.teamId,
          'p_action_url': '/teams',
          'p_idempotency_key':
              'team_join_${accept ? 'approved' : 'rejected'}:${request.id}',
        },
      );
    } catch (_) {
      // A failed notification must not fail the response action.
    }
  }

  /// Match invites where [teamId] is the **target** (invited) team.
  ///
  /// Filtered server-side (`.eq`) so realtime only ships this team's rows
  /// instead of the whole table being downloaded and filtered in Dart.
  Stream<List<TeamMatchRequest>> watchIncomingTeamMatchInvites(String teamId) {
    return guardSupabaseRealtimeStream(
      _sb
          .from('team_match_requests')
          .stream(primaryKey: ['id'])
          .eq('target_team_id', teamId)
          .asyncMap((rows) => _mapMatchRequestsForViewer(rows, teamId)),
    );
  }

  /// Match requests **sent by** [teamId].
  Stream<List<TeamMatchRequest>> watchOutgoingTeamMatchRequests(String teamId) {
    return guardSupabaseRealtimeStream(
      _sb
          .from('team_match_requests')
          .stream(primaryKey: ['id'])
          .eq('requesting_team_id', teamId)
          .asyncMap((rows) => _mapMatchRequestsForViewer(rows, teamId)),
    );
  }

  /// Teams where [userId] is captain or vice-captain (visible via RLS).
  Future<List<AppTeam>> fetchTeamsWhereUserIsOfficer(String userId) async {
    final rows = await _sb
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId)
        .inFilter('role', ['captain', 'vice_captain']);
    final ids = (rows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['team_id'].toString())
        .toSet()
        .toList();
    final out = <AppTeam>[];
    for (final id in ids) {
      final t = await _loadTeam(id);
      if (t != null) out.add(t);
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<void> sendMatchRequest({
    required String teamId,
    required String opponentTeamId,
    required String opponentName,
    required String matchId,
    List<String> proposedRoster = const [],
  }) async {
    final user = AppAuth.currentUser;
    if (user == null) return;
    final docRef = await _sb
        .from('team_match_requests')
        .insert(<String, dynamic>{
          'match_id': matchId,
          'requesting_team_id': teamId,
          'target_team_id': opponentTeamId,
          'created_by': user.id,
          'status': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    for (final playerId in proposedRoster) {
      await _sb.from('team_match_request_players').upsert(<String, dynamic>{
        'team_match_request_id': docRef['id'],
        'player_id': playerId,
      });
    }
    // Backend trigger handles team match request notifications.
  }

  /// Accept/decline a team match invitation.
  ///
  /// Routed through SECURITY DEFINER RPCs so the invited team's
  /// `match_teams` row + `match_team_rosters` are created atomically. Direct
  /// table UPDATEs were not enough: roster propagation drives both
  /// participation visibility (`can_view_match`, "My Matches") and player /
  /// team statistics aggregation. See migration
  /// `20260508120000_team_match_acceptance_rpc_and_backfill.sql`.
  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster = const [],
  }) async {
    if (accept) {
      await _sb.rpc(
        'accept_team_match_request',
        params: buildAcceptTeamMatchRpcParams(
          requestId: request.id,
          confirmedRoster: confirmedRoster,
        ),
      );
    } else {
      await _sb.rpc(
        'decline_team_match_request',
        params: buildDeclineTeamMatchRpcParams(requestId: request.id),
      );
    }
  }

  /// Cancel an outgoing team match request (host side).
  Future<void> cancelMatchRequest({required String requestId}) async {
    await _sb.rpc(
      'cancel_team_match_request',
      params: buildCancelTeamMatchRpcParams(requestId: requestId),
    );
  }

  Future<List<AppTeam>> searchTeams(String query, {int limit = 10}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final escaped = trimmed
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';

    final byName = await _sb
        .from('teams')
        .select('id')
        .ilike('name', pattern)
        .limit(limit * 3);
    final byCity = await _sb
        .from('teams')
        .select('id')
        .ilike('city', pattern)
        .limit(limit * 2);

    final ids = <String>{
      ...(byName as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
      ...(byCity as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty),
    };

    final matches = <AppTeam>[];
    for (final id in ids) {
      final team = await _loadTeam(id);
      if (team != null) matches.add(team);
    }

    final lower = trimmed.toLowerCase();
    matches.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      final aStarts = aName.startsWith(lower) ? 1 : 0;
      final bStarts = bName.startsWith(lower) ? 1 : 0;
      if (aStarts != bStarts) return bStarts - aStarts;
      return aName.compareTo(bName);
    });
    return matches.take(limit).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchPlayers(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final lower = trimmed.toLowerCase();
    final snap = await _sb.from('profiles').select().limit(200);
    final results = <Map<String, dynamic>>[];

    for (final raw in snap as List<dynamic>) {
      final data = raw as Map<String, dynamic>;
      final displayNameRaw = (data['display_name'] ?? data['nickname'] ?? '')
          .toString()
          .trim();
      final firstName = (data['first_name'] ?? '').toString().trim();
      final lastName = (data['last_name'] ?? '').toString().trim();
      final nickName = (data['nickname'] ?? '').toString().trim();
      final email = (data['email'] ?? '').toString().trim();

      final searchFields = <String>[
        displayNameRaw.toLowerCase(),
        firstName.toLowerCase(),
        lastName.toLowerCase(),
        '$firstName $lastName'.trim().toLowerCase(),
        nickName.toLowerCase(),
        email.toLowerCase(),
      ];

      final keywords = const <String>[];
      searchFields.addAll(keywords);

      bool matches = false;
      for (final field in searchFields) {
        if (field.isEmpty) continue;
        if (field.startsWith(lower) || field.contains(lower)) {
          matches = true;
          break;
        }
      }

      if (matches) {
        results.add({
          'id': data['id'],
          'displayName': displayNameRaw.isNotEmpty
              ? displayNameRaw
              : tr('il_64aee8c6cb'),
          'avatarUrl': (data['avatar_url'] ?? '').toString(),
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
        });
      }
    }

    results.sort((a, b) {
      String normalize(dynamic value) =>
          (value ?? '').toString().toLowerCase().trim();
      final aName = normalize(a['displayName']);
      final bName = normalize(b['displayName']);

      final aExact = aName == lower ? 1 : 0;
      final bExact = bName == lower ? 1 : 0;
      if (aExact != bExact) return bExact - aExact;

      final aStartsWith = aName.startsWith(lower) ? 1 : 0;
      final bStartsWith = bName.startsWith(lower) ? 1 : 0;
      if (aStartsWith != bStartsWith) return bStartsWith - aStartsWith;

      return aName.compareTo(bName);
    });

    return results.take(limit).toList();
  }

  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    final team = await _loadTeam(teamId);
    if (team == null) {
      throw Exception(tr('il_34d918824a'));
    }
    final teamNameForFeed = team.name;
    final memberIds = List<String>.from(team.memberIds);
    final viceIds = List<String>.from(team.viceCaptainIds);
    final captainId = team.captainId;

    if (!memberIds.contains(userId)) {
      throw Exception(tr('il_14041e10e5'));
    }

    // If captain is the last member, do not leave the team without a captain
    if (captainId == userId && memberIds.length == 1) {
      throw Exception(tr('il_b0792872ce'));
    }

    final updatedMembers = List<String>.from(memberIds)..remove(userId);
    final updatedVice = List<String>.from(viceIds)..remove(userId);

    // When captain leaves, assign captain to another member
    if (captainId == userId) {
      String? nextCaptain;
      if (updatedVice.isNotEmpty) {
        nextCaptain = updatedVice.first;
      } else if (updatedMembers.isNotEmpty) {
        nextCaptain = updatedMembers.first;
      }

      if (nextCaptain == null || nextCaptain.isEmpty) {
        throw Exception(tr('il_11f6a422ec'));
      }
      await _sb
          .from('team_members')
          .update({'role': 'captain'})
          .eq('team_id', teamId)
          .eq('user_id', nextCaptain);
      await _sb
          .from('team_members')
          .update({'role': 'member'})
          .eq('team_id', teamId)
          .eq('user_id', nextCaptain)
          .eq('role', 'vice_captain');
      // The departing captain handed the captaincy to this member.
      await _notifyTeamRoleChanged(
        teamId: teamId,
        memberId: nextCaptain,
        typeCode: 'team_new_captain',
      );
    }
    await _sb
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);

    // After successful leave, post to activity feed
    final userRow = await _sb
        .from('profiles')
        .select('display_name,nickname,first_name,last_name')
        .eq('id', userId)
        .maybeSingle();
    final userName =
        (userRow?['display_name'] ??
                userRow?['nickname'] ??
                '${userRow?['first_name'] ?? ''} ${userRow?['last_name'] ?? ''}'
                    .trim() ??
                tr('player'))
            .toString();

    await _publishTeamMovementNews(
      action: 'left_team',
      teamId: teamId,
      teamName: teamNameForFeed,
      userId: userId,
      userName: userName,
    );
  }

  Future<void> _publishTeamMovementNews({
    required String action, // joined_team | left_team
    required String teamId,
    required String teamName,
    required String userId,
    required String userName,
  }) async {
    // Activity feed table was a Firestore-only artifact.
    // Keep as a no-op while Firebase is being removed.
    return;
  }

  Future<List<TeamJoinRequest>> _mapJoinRequests(List<dynamic> rows) async {
    final out = <TeamJoinRequest>[];
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final teamId = (row['team_id'] ?? '').toString();
      final userId = (row['user_id'] ?? '').toString();
      final team = await _sb
          .from('teams')
          .select('name')
          .eq('id', teamId)
          .maybeSingle();
      final profile = await _sb
          .from('profiles')
          .select('display_name,nickname,first_name,last_name')
          .eq('id', userId)
          .maybeSingle();
      final userName =
          (profile?['display_name'] ??
                  profile?['nickname'] ??
                  '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
                      .trim() ??
                  tr('player'))
              .toString();
      out.add(
        TeamJoinRequest.fromJson(<String, dynamic>{
          'id': row['id'],
          'teamId': teamId,
          'teamName': (team?['name'] ?? '').toString(),
          'userId': userId,
          'userName': userName,
          'status': row['status'],
          'createdAt': row['created_at'],
        }),
      );
    }
    return out;
  }

  Future<List<TeamMatchRequest>> _mapMatchRequestsForViewer(
    List<dynamic> rows,
    String viewerTeamId,
  ) async {
    final reqs = rows
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList(growable: false);
    if (reqs.isEmpty) return const [];

    // The "other" team is whichever side the viewer is not.
    String otherIdFor(Map<String, dynamic> row) {
      final requestingId = (row['requesting_team_id'] ?? '').toString();
      final targetId = (row['target_team_id'] ?? '').toString();
      return viewerTeamId == requestingId ? targetId : requestingId;
    }

    final otherTeamIds = reqs
        .map(otherIdFor)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final requestIds = reqs.map((r) => r['id'].toString()).toList();

    // Batch the lookups: one query for opponent names, one for proposed
    // rosters — previously this was two awaited queries *per row* (N+1), which
    // added latency to every realtime emission.
    final namesById = <String, String>{};
    if (otherTeamIds.isNotEmpty) {
      final teamRows = await _sb
          .from('teams')
          .select('id,name')
          .inFilter('id', otherTeamIds);
      for (final raw in teamRows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        namesById[row['id'].toString()] = (row['name'] ?? '').toString();
      }
    }

    final rosterByRequestId = <String, List<String>>{};
    if (requestIds.isNotEmpty) {
      final rosterRows = await _sb
          .from('team_match_request_players')
          .select('team_match_request_id,player_id')
          .inFilter('team_match_request_id', requestIds);
      for (final raw in rosterRows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        final rid = row['team_match_request_id'].toString();
        (rosterByRequestId[rid] ??= <String>[]).add(
          row['player_id'].toString(),
        );
      }
    }

    return reqs.map((row) {
      final requestId = row['id'].toString();
      final otherTeamId = otherIdFor(row);
      return TeamMatchRequest.fromJson(<String, dynamic>{
        'id': requestId,
        'matchId': row['match_id'],
        'teamId': viewerTeamId,
        'opponentTeamId': otherTeamId,
        'opponentName': namesById[otherTeamId] ?? '',
        'createdBy': row['created_by'],
        'status': row['status'],
        'createdAt': row['created_at'],
        'proposedRoster': rosterByRequestId[requestId] ?? const <String>[],
      });
    }).toList();
  }
}
