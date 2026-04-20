import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import '../../data/models/app_team.dart';
import '../../data/models/team_invite.dart';
import '../../data/models/team_join_request.dart';
import '../../data/models/team_match_request.dart';
import '../../../notifications/data/models/notification.dart';
import '../../../notifications/data/services/notification_service.dart';
import 'package:flap_app/core/auth/app_auth.dart';

class TeamService {
  TeamService._();
  static final TeamService _instance = TeamService._();
  factory TeamService() => _instance;

  SupabaseClient get _sb => Supabase.instance.client;

  Future<AppTeam?> _loadTeam(String teamId) async {
    final teamRow = await _sb.from('teams').select().eq('id', teamId).maybeSingle();
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

  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return _sb
        .from('team_members')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
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
    });
  }

  Future<List<AppTeam>> fetchUserTeams(String userId) async {
    final rows = await _sb.from('team_members').select('team_id').eq('user_id', userId);
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
      throw Exception('Користувач не авторизований');
    }

    final existingMemberships = await _sb
        .from('team_members')
        .select('id')
        .eq('user_id', user.id);
    if ((existingMemberships as List<dynamic>).length >= 3) {
      throw Exception('Максимум 3 команди на гравця');
    }

    final inserted = await _sb
        .from('teams')
        .insert(<String, dynamic>{
          'name': name,
          'description': description,
          'city': city,
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
      await _sb.from('teams').update(<String, dynamic>{
        'logo_url': logoUrl,
      }).eq('id', teamId);
    }

    return teamId;
  }

  Future<String> _uploadTeamLogo(String teamId, Uint8List bytes) async {
    final uid = AppAuth.currentUser?.id;
    if (uid == null) {
      throw Exception('Користувач не авторизований');
    }
    final path =
        '$uid/$teamId-${DateTime.now().millisecondsSinceEpoch}.png';
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
      });
    } else {
      await _sb
          .from('team_members')
          .update(<String, dynamic>{'role': 'member'})
          .eq('team_id', teamId)
          .eq('user_id', memberId)
          .eq('role', 'vice_captain');
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
    if (city != null) updates['city'] = city;
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
    for (final uid in userIds) {
      await NotificationService().sendNotification(
        AppNotification.teamInvite(
          userId: uid,
          teamId: teamId,
          teamName: teamName,
        ),
      );
    }
  }

  Stream<List<TeamInvite>> watchInvites(String userId) {
    return _sb
        .from('team_invites')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      final invites = <TeamInvite>[];
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        if ((row['user_id'] ?? '').toString() != userId) continue;
        if ((row['status'] ?? '').toString() != 'pending') continue;
        final teamId = (row['team_id'] ?? '').toString();
        final team = await _sb.from('teams').select('name').eq('id', teamId).maybeSingle();
        invites.add(TeamInvite.fromJson(<String, dynamic>{
          'id': row['id'],
          'teamId': teamId,
          'teamName': (team?['name'] ?? '').toString(),
          'userId': row['user_id'],
          'invitedBy': row['invited_by'],
          'status': row['status'],
          'createdAt': row['created_at'],
        }));
      }
      return invites;
    });
  }

  Future<void> respondToInvite({
    required TeamInvite invite,
    required bool accept,
  }) async {
    final userTeams = await fetchUserTeams(invite.userId);
    if (accept && userTeams.length >= 3) {
      throw Exception('Максимум 3 команди на гравця');
    }
    await _sb.from('team_invites').update(<String, dynamic>{
      'status': accept ? 'accepted' : 'declined',
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', invite.id);

    if (accept) {
      await _sb.from('team_members').upsert(<String, dynamic>{
        'team_id': invite.teamId,
        'user_id': invite.userId,
        'role': 'member',
      });
    }

    if (accept) {
      final userRow = await _sb
          .from('profiles')
          .select('display_name, nickname, first_name, last_name')
          .eq('id', invite.userId)
          .maybeSingle();
      final userName = (userRow?['display_name'] ??
              userRow?['nickname'] ??
              '${userRow?['first_name'] ?? ''} ${userRow?['last_name'] ?? ''}'.trim() ??
              'Player')
          .toString();
      await _publishTeamMovementNews(
        action: 'joined_team',
        teamId: invite.teamId,
        teamName: invite.teamName,
        userId: invite.userId,
        userName: userName,
      );
    }
  }

  Stream<List<TeamJoinRequest>> watchJoinRequests(String teamId) {
    return _sb
        .from('team_join_requests')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) {
      final filtered = (rows as List<dynamic>).where((raw) {
        final row = raw as Map<String, dynamic>;
        return (row['team_id'] ?? '').toString() == teamId &&
            (row['status'] ?? '').toString() == 'pending';
      }).toList();
      return _mapJoinRequests(filtered);
    });
  }

  Stream<TeamJoinRequest?> watchMyJoinRequest(
      String teamId, String userId) {
    return _sb
        .from('team_join_requests')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      final filtered = (rows as List<dynamic>).where((raw) {
        final row = raw as Map<String, dynamic>;
        return (row['team_id'] ?? '').toString() == teamId &&
            (row['user_id'] ?? '').toString() == userId;
      }).toList();
      final mapped = await _mapJoinRequests(filtered);
      if (mapped.isEmpty) return null;
      mapped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return mapped.first;
    });
  }

  Future<void> requestToJoinTeam({
    required String teamId,
    required String teamName,
  }) async {
    final user = AppAuth.currentUser;
    if (user == null) {
      throw Exception('Потрібна авторизація');
    }
    final team = await _loadTeam(teamId);
    if (team == null) {
      throw Exception('Команду не знайдено');
    }
    if (team.memberIds.contains(user.id)) {
      throw Exception('Ви вже у цій команді');
    }

    final pendingExisting = await _sb
        .from('team_join_requests')
        .select('id')
        .eq('team_id', teamId)
        .eq('user_id', user.id)
        .eq('status', 'pending');
    if ((pendingExisting as List).isNotEmpty) {
      throw Exception('Запит вже надіслано');
    }

    final requesterName =
        (user.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? (user.userMetadata!['full_name'] as String).trim()
            : (user.email?.split('@').first ?? 'Player');
    final reqRef = await _sb.from('team_join_requests').insert(<String, dynamic>{
      'team_id': teamId,
      'user_id': user.id,
      'status': 'pending',
      'message': requesterName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

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
            requestId: reqRef['id'].toString(),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> respondToJoinRequest({
    required TeamJoinRequest request,
    required bool accept,
  }) async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) return;
    final team = await _loadTeam(request.teamId);
    if (team == null) {
      throw Exception('Команду не знайдено');
    }
    final captainId = team.captainId;
    final viceIds = team.viceCaptainIds;
    final canManage =
        captainId == currentUser.id || viceIds.contains(currentUser.id);
    if (!canManage) {
      throw Exception('Недостатньо прав');
    }

    await _sb.from('team_join_requests').update({
      'status': accept ? 'accepted' : 'declined',
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', request.id);

    if (accept) {
      await _sb.from('team_members').upsert(<String, dynamic>{
        'team_id': request.teamId,
        'user_id': request.userId,
        'role': 'member',
      });
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
  }

  Stream<List<TeamMatchRequest>> watchMatchRequests(String teamId) {
    return _sb
        .from('team_match_requests')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) {
      final filtered = (rows as List<dynamic>).where((raw) {
        final row = raw as Map<String, dynamic>;
        return (row['requesting_team_id'] ?? '').toString() == teamId &&
            (row['status'] ?? '').toString() == 'pending';
      }).toList();
      return _mapMatchRequests(filtered);
    });
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
    final docRef = await _sb.from('team_match_requests').insert(<String, dynamic>{
      'match_id': matchId,
      'requesting_team_id': teamId,
      'target_team_id': opponentTeamId,
      'created_by': user.id,
      'status': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();
    for (final playerId in proposedRoster) {
      await _sb.from('team_match_request_players').upsert(<String, dynamic>{
        'team_match_request_id': docRef['id'],
        'player_id': playerId,
      });
    }
    try {
      final team = await _loadTeam(teamId);
      if (team != null) {
        final captainId = team.captainId;
        final viceCaptainIds = team.viceCaptainIds;
        final recipients = {
          captainId,
          ...viceCaptainIds,
        }.where((id) => id.isNotEmpty).toSet();

        for (final recipient in recipients) {
          await NotificationService().sendNotification(
            AppNotification.teamMatchRequest(
              userId: recipient,
              opponentTeamName: opponentName,
              matchId: matchId,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> respondToMatchRequest({
    required TeamMatchRequest request,
    required bool accept,
    List<String> confirmedRoster = const [],
  }) async {
    await _sb.from('team_match_requests').update({
      'status': accept ? 'accepted' : 'declined',
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', request.id);

    String? assignedTeamKey;

    if (accept) {
      assignedTeamKey = 'team';
    }

    if (accept && assignedTeamKey != null && confirmedRoster.isNotEmpty) {
      final team = await _loadTeam(request.teamId);
      final teamName = team?.name ?? 'Team';
      final notif = NotificationService();
      for (final playerId in confirmedRoster) {
        await notif.sendTeamRosterInvite(
          toUserId: playerId,
          matchId: request.matchId,
          teamName: teamName,
          teamKey: assignedTeamKey,
        );
      }
    }
  }

  Future<List<AppTeam>> searchTeams(String query, {int limit = 10}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    final snap = await _sb.from('teams').select().limit(200);
    final matches = <AppTeam>[];
    for (final raw in snap as List<dynamic>) {
      final data = raw as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString();
      final city = (data['city'] ?? '').toString();
      if (name.toLowerCase().contains(trimmed) ||
          city.toLowerCase().contains(trimmed)) {
        final t = await _loadTeam((data['id'] ?? '').toString());
        if (t != null) matches.add(t);
      }
    }
    matches.sort((a, b) => a.name.compareTo(b.name));
    return matches.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> searchPlayers(String query,
      {int limit = 10}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final lower = trimmed.toLowerCase();
    final snap = await _sb.from('profiles').select().limit(200);
    final results = <Map<String, dynamic>>[];

    for (final raw in snap as List<dynamic>) {
      final data = raw as Map<String, dynamic>;
      final displayNameRaw =
          (data['display_name'] ?? data['nickname'] ?? '')
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
          'displayName':
              displayNameRaw.isNotEmpty ? displayNameRaw : tr('il_64aee8c6cb'),
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
      throw Exception(
        tr('il_14041e10e5'),
      );
    }

    // Якщо капітан останній у команді — не даємо "осиротити" команду
    if (captainId == userId && memberIds.length == 1) {
      throw Exception(
        tr('il_b0792872ce'),
      );
    }

    final updatedMembers = List<String>.from(memberIds)..remove(userId);
    final updatedVice = List<String>.from(viceIds)..remove(userId);

    // Якщо виходить капітан — передаємо капітанство іншому учаснику
    if (captainId == userId) {
      String? nextCaptain;
      if (updatedVice.isNotEmpty) {
        nextCaptain = updatedVice.first;
      } else if (updatedMembers.isNotEmpty) {
        nextCaptain = updatedMembers.first;
      }

      if (nextCaptain == null || nextCaptain.isEmpty) {
        throw Exception(
          tr('il_11f6a422ec'),
        );
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
    }
  await _sb
      .from('team_members')
      .delete()
      .eq('team_id', teamId)
      .eq('user_id', userId);

  // Після успішного виходу — новина в activity feed
  final userRow = await _sb
      .from('profiles')
      .select('display_name,nickname,first_name,last_name')
      .eq('id', userId)
      .maybeSingle();
  final userName = (userRow?['display_name'] ??
          userRow?['nickname'] ??
          '${userRow?['first_name'] ?? ''} ${userRow?['last_name'] ?? ''}'.trim() ??
          'Player')
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
      final team = await _sb.from('teams').select('name').eq('id', teamId).maybeSingle();
      final profile = await _sb
          .from('profiles')
          .select('display_name,nickname,first_name,last_name')
          .eq('id', userId)
          .maybeSingle();
      final userName = (profile?['display_name'] ??
              profile?['nickname'] ??
              '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'.trim() ??
              'Player')
          .toString();
      out.add(TeamJoinRequest.fromJson(<String, dynamic>{
        'id': row['id'],
        'teamId': teamId,
        'teamName': (team?['name'] ?? '').toString(),
        'userId': userId,
        'userName': userName,
        'status': row['status'],
        'createdAt': row['created_at'],
      }));
    }
    return out;
  }

  Future<List<TeamMatchRequest>> _mapMatchRequests(List<dynamic> rows) async {
    final out = <TeamMatchRequest>[];
    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final requestId = row['id'].toString();
      final targetTeamId = (row['target_team_id'] ?? '').toString();
      final targetTeam = await _sb
          .from('teams')
          .select('name')
          .eq('id', targetTeamId)
          .maybeSingle();
      final rosterRows = await _sb
          .from('team_match_request_players')
          .select('player_id')
          .eq('team_match_request_id', requestId);
      out.add(TeamMatchRequest.fromJson(<String, dynamic>{
        'id': requestId,
        'matchId': row['match_id'],
        'teamId': row['requesting_team_id'],
        'opponentTeamId': targetTeamId,
        'opponentName': (targetTeam?['name'] ?? '').toString(),
        'createdBy': row['created_by'],
        'status': row['status'],
        'createdAt': row['created_at'],
        'proposedRoster': (rosterRows as List<dynamic>)
            .map((r) => (r as Map<String, dynamic>)['player_id'].toString())
            .toList(),
      }));
    }
    return out;
  }
}

