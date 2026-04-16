import 'package:flap_app/models/app_team.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/models/team_invite.dart';
import 'package:flap_app/models/team_join_request.dart';
import 'package:flap_app/models/team_match_request.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teams_remote_data_source.dart';

class SupabaseTeamsRemoteDataSource implements TeamsRemoteDataSource {
  SupabaseClient get _c => Supabase.instance.client;

  Future<AppTeam> _hydrateTeam(Map<String, dynamic> teamRow) async {
    final teamId = teamRow['id'].toString();
    final memberRows = await _c
        .from('team_members')
        .select('user_id, role')
        .eq('team_id', teamId);
    final members = memberRows.cast<Map<String, dynamic>>();
    final memberIds = members.map((e) => e['user_id'].toString()).toList();
    final viceCaptains = members
        .where((e) => (e['role']?.toString() ?? '') == 'ADMIN')
        .map((e) => e['user_id'].toString())
        .toList();
    final enriched = Map<String, dynamic>.from(teamRow)
      ..['member_ids'] = memberIds
      ..['vice_captain_ids'] = viceCaptains
      ..['captain_id'] = (teamRow['owner_id'] ?? '').toString();
    return AppTeam.fromSupabaseRow(enriched);
  }

  Future<List<AppTeam>> _hydrateTeams(List<Map<String, dynamic>> rows) async {
    final out = <AppTeam>[];
    for (final row in rows) {
      out.add(await _hydrateTeam(row));
    }
    return out;
  }

  @override
  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return _c
        .from('team_members')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .asyncMap((raw) async {
      final ids = (raw as List)
          .cast<Map>()
          .map((e) => e['team_id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (ids.isEmpty) return const <AppTeam>[];
      final teams = await _c.from('teams').select().inFilter('id', ids);
      return _hydrateTeams(teams.cast<Map<String, dynamic>>());
    });
  }

  @override
  Future<List<AppTeam>> fetchUserTeams(String userId) async {
    final memberRows = await _c
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId);
    final ids = (memberRows as List)
        .cast<Map>()
        .map((e) => e['team_id']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
    if (ids.isEmpty) return const [];
    final teamRows = await _c.from('teams').select().inFilter('id', ids);
    return _hydrateTeams(teamRows.cast<Map<String, dynamic>>());
  }

  @override
  Future<AppTeam?> fetchTeam(String teamId) async {
    final row = await _c.from('teams').select().eq('id', teamId).maybeSingle();
    if (row == null) return null;
    return _hydrateTeam(Map<String, dynamic>.from(row));
  }

  @override
  Stream<AppTeam?> watchTeam(String teamId) {
    return _c
        .from('teams')
        .stream(primaryKey: const ['id'])
        .eq('id', teamId)
        .asyncMap((raw) async {
      final rows = (raw as List).cast<Map>();
      if (rows.isEmpty) return null;
      return _hydrateTeam(Map<String, dynamic>.from(rows.first));
    });
  }

  @override
  Stream<List<AppTeam>> watchTeamsLeaderboard() {
    return _c.from('teams').stream(primaryKey: const ['id']).asyncMap((raw) async {
      final rows = (raw as List).cast<Map>();
      final teams = await _hydrateTeams(
        rows.map((e) => Map<String, dynamic>.from(e)).toList(),
      );
      teams.sort((a, b) {
        final w = b.wins.compareTo(a.wins);
        if (w != 0) return w;
        return a.name.compareTo(b.name);
      });
      return teams;
    });
  }

  @override
  Future<String> createTeam({
    required String name,
    required String description,
    String? city,
    bool isPublic = true,
  }) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw Exception(I18n.inline('Потрібна авторизація', 'Sign-in required'));
    final row = await _c
        .from('teams')
        .insert({
          'name': name,
          'description': description,
          'owner_id': uid,
          'city': city,
          'is_public': isPublic,
        })
        .select('id')
        .single();
    return row['id'].toString();
  }

  @override
  Future<void> updateTeamLogoUrl(String teamId, String logoUrl) async {
    await _c.from('teams').update({
      'logo_url': logoUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', teamId);
  }

  @override
  Future<void> updateTeamInfo({
    required String teamId,
    String? name,
    String? description,
    String? city,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) {
      updates['name'] = name;
      updates['name_lower'] = name.toLowerCase();
    }
    if (description != null) updates['description'] = description;
    if (city != null) updates['city'] = city.isEmpty ? null : city;
    if (isPublic != null) updates['is_public'] = isPublic;
    await _c.from('teams').update(updates).eq('id', teamId);
  }

  @override
  Future<void> insertTeamInvites(List<TeamInvite> invites) async {
    for (final inv in invites) {
      await _c.from('team_memberships').upsert({
        'team_id': inv.teamId,
        'user_id': inv.userId,
        'type': 'INVITE',
        'status': 'PENDING',
        'initiated_by': inv.invitedBy,
        'message': null,
      });
    }
  }

  @override
  Stream<List<TeamInvite>> watchPendingInvitesForUser(String userId) {
    return _c
        .from('team_memberships')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .asyncMap((raw) async {
      final rows = (raw as List).cast<Map>();
      final filtered = rows.where((e) =>
          (e['type']?.toString() ?? '') == 'INVITE' &&
          (e['status']?.toString() ?? '') == 'PENDING');
      final out = <TeamInvite>[];
      for (final row in filtered) {
        final teamId = row['team_id']?.toString() ?? '';
        final team = teamId.isEmpty
            ? null
            : await _c.from('teams').select('name').eq('id', teamId).maybeSingle();
        out.add(
          TeamInvite(
            id: row['id'].toString(),
            teamId: teamId,
            teamName: (team?['name'] ?? '').toString(),
            userId: row['user_id']?.toString() ?? '',
            invitedBy: row['initiated_by']?.toString() ?? '',
            status: TeamInviteStatus.pending,
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          ),
        );
      }
      return out;
    });
  }

  @override
  Future<void> respondToInviteRpc({
    required String inviteId,
    required bool accept,
  }) async {
    await _c
        .from('team_memberships')
        .update({'status': accept ? 'ACCEPTED' : 'REJECTED'})
        .eq('id', inviteId);
  }

  @override
  Stream<List<TeamJoinRequest>> watchPendingJoinRequestsForTeam(String teamId) {
    return _c
        .from('team_memberships')
        .stream(primaryKey: const ['id'])
        .eq('team_id', teamId)
        .asyncMap((raw) async {
      final rows = (raw as List).cast<Map>();
      final team = await _c.from('teams').select('name').eq('id', teamId).maybeSingle();
      final teamName = (team?['name'] ?? '').toString();
      final filtered = rows.where((e) =>
          (e['type']?.toString() ?? '') == 'REQUEST' &&
          (e['status']?.toString() ?? '') == 'PENDING');
      final out = <TeamJoinRequest>[];
      for (final row in filtered) {
        final userId = row['user_id']?.toString() ?? '';
        final profile = userId.isEmpty
            ? null
            : await _c
                .from('user_profiles')
                .select('display_name, first_name, last_name')
                .eq('id', userId)
                .maybeSingle();
        final displayName = (profile?['display_name'] ??
                '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}')
            .toString()
            .trim();
        out.add(
          TeamJoinRequest(
            id: row['id'].toString(),
            teamId: teamId,
            teamName: teamName,
            userId: userId,
            userName: displayName.isEmpty ? 'Player' : displayName,
            status: TeamJoinRequestStatus.pending,
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
          ),
        );
      }
      return out;
    });
  }

  @override
  Stream<TeamJoinRequest?> watchLatestJoinRequestForUserOnTeam({
    required String teamId,
    required String userId,
  }) {
    return _c
        .from('team_memberships')
        .stream(primaryKey: const ['id'])
        .eq('team_id', teamId)
        .asyncMap((raw) async {
      final rows = (raw as List).cast<Map>();
      final team = await _c.from('teams').select('name').eq('id', teamId).maybeSingle();
      final teamName = (team?['name'] ?? '').toString();
      final mine = rows
          .where((e) =>
              (e['user_id']?.toString() ?? '') == userId &&
              (e['type']?.toString() ?? '') == 'REQUEST')
          .map((e) => TeamJoinRequest(
                id: e['id'].toString(),
                teamId: teamId,
                teamName: teamName,
                userId: userId,
                userName: '',
                status: (e['status']?.toString() ?? '') == 'ACCEPTED'
                    ? TeamJoinRequestStatus.accepted
                    : (e['status']?.toString() ?? '') == 'REJECTED'
                        ? TeamJoinRequestStatus.declined
                        : TeamJoinRequestStatus.pending,
                createdAt:
                    DateTime.tryParse(e['created_at']?.toString() ?? '') ?? DateTime.now(),
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mine.isEmpty) return null;
      return mine.first;
    });
  }

  @override
  Future<String> insertJoinRequest(TeamJoinRequest request) async {
    final res = await _c
        .from('team_memberships')
        .insert({
          'team_id': request.teamId,
          'user_id': request.userId,
          'type': 'REQUEST',
          'status': 'PENDING',
          'initiated_by': request.userId,
          'message': null,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  @override
  Future<bool> hasPendingJoinRequest(String teamId, String userId) async {
    final row = await _c
        .from('team_memberships')
        .select('id')
        .eq('team_id', teamId)
        .eq('user_id', userId)
        .eq('type', 'REQUEST')
        .eq('status', 'PENDING')
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> respondToJoinRequestRpc({
    required String requestId,
    required bool accept,
  }) async {
    await _c
        .from('team_memberships')
        .update({'status': accept ? 'ACCEPTED' : 'REJECTED'})
        .eq('id', requestId);
  }

  @override
  Stream<List<TeamMatchRequest>> watchPendingMatchRequestsForTeam(
      String teamId) {
    return const Stream<List<TeamMatchRequest>>.empty();
  }

  @override
  Future<void> insertMatchRequest(TeamMatchRequest request) async {
    throw UnimplementedError(
      'Team match requests are not part of the current Supabase schema.',
    );
  }

  @override
  Future<void> updateMatchRequestStatus({
    required String requestId,
    required bool accepted,
  }) async {
    throw UnimplementedError(
      'Team match requests are not part of the current Supabase schema.',
    );
  }

  @override
  Future<List<AppTeam>> searchTeamsLocalFilter(String query, {int limit = 10}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    final rows = await _c
        .from('teams')
        .select()
        .eq('is_public', true)
        .isFilter('deleted_at', null)
        .limit(300);
    final matches = <AppTeam>[];
    for (final r in (rows as List).cast<Map>()) {
      final team = await _hydrateTeam(Map<String, dynamic>.from(r));
      final name = team.name.toLowerCase();
      final city = (team.city ?? '').toLowerCase();
      if (name.contains(trimmed) || city.contains(trimmed)) {
        matches.add(team);
      }
    }
    matches.sort((a, b) => a.name.compareTo(b.name));
    return matches.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> searchPlayersProfiles(
    String query, {
    int limit = 10,
    List<String>? positionsAnyOf,
  }) async {
    final trimmed = query.trim();
    final lower = trimmed.toLowerCase();
    final hasText = trimmed.isNotEmpty;
    final hasPosition =
        positionsAnyOf != null && positionsAnyOf.isNotEmpty;

    if (!hasText && !hasPosition) {
      return [];
    }

    dynamic request = _c.from('user_profiles').select(
          'id, display_name, first_name, last_name, email, avatar_url, position',
        );
    if (hasPosition) {
      request = request.inFilter('position', positionsAnyOf);
    }
    final rows = await request.limit(hasPosition ? 400 : 200);

    String normalize(dynamic value) =>
        (value ?? '').toString().toLowerCase().trim();

    final results = <Map<String, dynamic>>[];
    for (final r in (rows as List).cast<Map>()) {
      final m = Map<String, dynamic>.from(r);
      final firstName =
          (m['first_name'] ?? m['name'] ?? '').toString().trim();
      final lastName =
          (m['last_name'] ?? m['surname'] ?? '').toString().trim();
      final displayNameRaw = (m['display_name'] ??
              (firstName.isEmpty && lastName.isEmpty
                  ? ''
                  : '$firstName $lastName'.trim()))
          .toString()
          .trim();
      final email = (m['email'] ?? '').toString().trim();
      if (hasText) {
        final searchFields = <String>[
          displayNameRaw.toLowerCase(),
          firstName.toLowerCase(),
          lastName.toLowerCase(),
          '$firstName $lastName'.trim().toLowerCase(),
          email.toLowerCase(),
        ];
        var matches = false;
        for (final field in searchFields) {
          if (field.isEmpty) continue;
          if (field.startsWith(lower) || field.contains(lower)) {
            matches = true;
            break;
          }
        }
        if (!matches) continue;
      }
      results.add({
        'id': m['id'].toString(),
        'displayName': displayNameRaw.isNotEmpty
            ? displayNameRaw
            : I18n.inline('Гравець', 'Player'),
        'avatarUrl': (m['avatar_url'] ?? '').toString(),
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'profilePosition': (m['position'] ?? '').toString(),
      });
    }
    if (hasText) {
      results.sort((a, b) {
        final aName = normalize(a['displayName']);
        final bName = normalize(b['displayName']);
        final aExact = aName == lower ? 1 : 0;
        final bExact = bName == lower ? 1 : 0;
        if (aExact != bExact) return bExact - aExact;
        final aStarts = aName.startsWith(lower) ? 1 : 0;
        final bStarts = bName.startsWith(lower) ? 1 : 0;
        if (aStarts != bStarts) return bStarts - aStarts;
        return aName.compareTo(bName);
      });
    } else {
      results.sort((a, b) => normalize(a['displayName'])
          .compareTo(normalize(b['displayName'])));
    }
    return results.take(limit).toList();
  }

  @override
  Future<void> leaveTeamRpc(String teamId) async {
    final uid = _c.auth.currentUser?.id;
    if (uid == null) throw Exception(I18n.inline('Потрібна авторизація', 'Sign-in required'));
    final team = await _c.from('teams').select('owner_id').eq('id', teamId).maybeSingle();
    if (team == null) {
      throw Exception('team_not_found');
    }
    final ownerId = (team['owner_id'] ?? '').toString();
    if (ownerId != uid) {
      await _c
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', uid);
      return;
    }
    final members = await _c
        .from('team_members')
        .select('id, user_id, role, joined_at')
        .eq('team_id', teamId);
    final rows = members.cast<Map<String, dynamic>>();
    final others = rows.where((e) => (e['user_id'] ?? '').toString() != uid).toList();
    if (others.isEmpty) {
      throw Exception('last_member');
    }
    others.sort((a, b) {
      final aRole = (a['role'] ?? '').toString();
      final bRole = (b['role'] ?? '').toString();
      final score = (String role) => role == 'ADMIN' ? 0 : 1;
      final c = score(aRole).compareTo(score(bRole));
      if (c != 0) return c;
      final at = DateTime.tryParse(a['joined_at']?.toString() ?? '') ?? DateTime.now();
      final bt = DateTime.tryParse(b['joined_at']?.toString() ?? '') ?? DateTime.now();
      return at.compareTo(bt);
    });
    final successorId = others.first['user_id'].toString();
    await _c.from('teams').update({'owner_id': successorId}).eq('id', teamId);
    await _c
        .from('team_members')
        .update({'role': 'OWNER'})
        .eq('team_id', teamId)
        .eq('user_id', successorId);
    await _c
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', uid);
  }

  @override
  Future<void> insertTeamActivity({
    required String type,
    required String teamId,
    required String teamName,
    required String userId,
    required String userName,
  }) async {
    // Optional activity feed table is not part of the current schema.
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileForDisplay(String userId) async {
    final row = await _c
        .from('user_profiles')
        .select('display_name, first_name, last_name, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final dn = (m['display_name'] ?? '').toString().trim();
    final n = (m['first_name'] ?? m['name'] ?? '').toString().trim();
    final s = (m['last_name'] ?? m['surname'] ?? '').toString().trim();
    final combined = '$n $s'.trim();
    final display = dn.isNotEmpty
        ? dn
        : combined.isNotEmpty
            ? combined
            : I18n.inline('Гравець', 'Player');
    return {
      'displayName': display,
      'avatarUrl': (m['avatar_url'] ?? '').toString(),
    };
  }

  @override
  Future<String?> fetchProfileDisplayName(String userId) async {
    final row = await _c
        .from('user_profiles')
        .select('display_name, first_name, last_name')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final dn = (m['display_name'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final n = (m['first_name'] ?? m['name'] ?? '').toString().trim();
    final s = (m['last_name'] ?? m['surname'] ?? '').toString().trim();
    final combined = '$n $s'.trim();
    return combined.isNotEmpty ? combined : null;
  }

  @override
  Future<void> addViceCaptain(String teamId, String userId) async {
    await _c
        .from('team_members')
        .update({'role': 'ADMIN'})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  @override
  Future<void> removeViceCaptain(String teamId, String userId) async {
    await _c
        .from('team_members')
        .update({'role': 'PLAYER'})
        .eq('team_id', teamId)
        .eq('user_id', userId)
        .neq('role', 'OWNER');
  }

  @override
  Future<void> applyStandingsAfterTeamMatch({
    required Match match,
    required int teamAScore,
    required int teamBScore,
    required Map<String, int> goalsByPlayer,
  }) async {
    if (match.teamAId == null || match.teamBId == null) return;
    final aRow = await _c
        .from('teams')
        .select('id, wins, losses, draws, matches_played')
        .eq('id', match.teamAId!)
        .maybeSingle();
    final bRow = await _c
        .from('teams')
        .select('id, wins, losses, draws, matches_played')
        .eq('id', match.teamBId!)
        .maybeSingle();
    if (aRow == null || bRow == null) return;
    final resultA = teamAScore.compareTo(teamBScore);
    final aWins = (aRow['wins'] as num?)?.toInt() ?? 0;
    final aLosses = (aRow['losses'] as num?)?.toInt() ?? 0;
    final aDraws = (aRow['draws'] as num?)?.toInt() ?? 0;
    final aPlayed = (aRow['matches_played'] as num?)?.toInt() ?? 0;
    final bWins = (bRow['wins'] as num?)?.toInt() ?? 0;
    final bLosses = (bRow['losses'] as num?)?.toInt() ?? 0;
    final bDraws = (bRow['draws'] as num?)?.toInt() ?? 0;
    final bPlayed = (bRow['matches_played'] as num?)?.toInt() ?? 0;
    await _c.from('teams').update({
      'wins': aWins + (resultA > 0 ? 1 : 0),
      'losses': aLosses + (resultA < 0 ? 1 : 0),
      'draws': aDraws + (resultA == 0 ? 1 : 0),
      'matches_played': aPlayed + 1,
    }).eq('id', match.teamAId!);
    await _c.from('teams').update({
      'wins': bWins + (resultA < 0 ? 1 : 0),
      'losses': bLosses + (resultA > 0 ? 1 : 0),
      'draws': bDraws + (resultA == 0 ? 1 : 0),
      'matches_played': bPlayed + 1,
    }).eq('id', match.teamBId!);
  }
}
