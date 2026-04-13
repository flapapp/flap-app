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

  @override
  Stream<List<AppTeam>> watchUserTeams(String userId) {
    return _c.from('teams').stream(primaryKey: const ['id']).map((raw) {
      final rows = (raw as List).cast<Map>();
      return rows
          .map((e) => AppTeam.fromSupabaseRow(Map<String, dynamic>.from(e)))
          .where((t) => t.memberIds.contains(userId))
          .toList();
    });
  }

  @override
  Future<List<AppTeam>> fetchUserTeams(String userId) async {
    final rows = await _c
        .from('teams')
        .select()
        .contains('member_ids', [userId]);
    return (rows as List)
        .cast<Map>()
        .map((e) => AppTeam.fromSupabaseRow(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<AppTeam?> fetchTeam(String teamId) async {
    final row = await _c.from('teams').select().eq('id', teamId).maybeSingle();
    if (row == null) return null;
    return AppTeam.fromSupabaseRow(Map<String, dynamic>.from(row));
  }

  @override
  Stream<AppTeam?> watchTeam(String teamId) {
    return _c
        .from('teams')
        .stream(primaryKey: const ['id'])
        .eq('id', teamId)
        .map((raw) {
      final rows = (raw as List).cast<Map>();
      if (rows.isEmpty) return null;
      return AppTeam.fromSupabaseRow(Map<String, dynamic>.from(rows.first));
    });
  }

  @override
  Stream<List<AppTeam>> watchTeamsLeaderboard() {
    return _c.from('teams').stream(primaryKey: const ['id']).map((raw) {
      final rows = (raw as List).cast<Map>();
      final teams = rows
          .map((e) => AppTeam.fromSupabaseRow(Map<String, dynamic>.from(e)))
          .toList();
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
    final res = await _c.rpc(
      'team_create',
      params: {
        'p_name': name,
        'p_description': description,
        'p_city': city ?? '',
        'p_is_public': isPublic,
      },
    );
    return res as String;
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
      await _c.from('team_invites').insert(inv.toSupabaseInsert());
    }
  }

  @override
  Stream<List<TeamInvite>> watchPendingInvitesForUser(String userId) {
    return _c
        .from('team_invites')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .map((raw) {
      final rows = (raw as List).cast<Map>();
      return rows
          .map((e) => TeamInvite.fromSupabaseRow(Map<String, dynamic>.from(e)))
          .where((i) => i.status == TeamInviteStatus.pending)
          .toList();
    });
  }

  @override
  Future<void> respondToInviteRpc({
    required String inviteId,
    required bool accept,
  }) async {
    await _c.rpc(
      'team_invite_respond',
      params: {
        'p_invite_id': inviteId,
        'p_accept': accept,
      },
    );
  }

  @override
  Stream<List<TeamJoinRequest>> watchPendingJoinRequestsForTeam(String teamId) {
    return _c
        .from('team_join_requests')
        .stream(primaryKey: const ['id'])
        .eq('team_id', teamId)
        .map((raw) {
      final rows = (raw as List).cast<Map>();
      return rows
          .map((e) =>
              TeamJoinRequest.fromSupabaseRow(Map<String, dynamic>.from(e)))
          .where((r) => r.status == TeamJoinRequestStatus.pending)
          .toList();
    });
  }

  @override
  Stream<TeamJoinRequest?> watchLatestJoinRequestForUserOnTeam({
    required String teamId,
    required String userId,
  }) {
    return _c
        .from('team_join_requests')
        .stream(primaryKey: const ['id'])
        .eq('team_id', teamId)
        .map((raw) {
      final rows = (raw as List).cast<Map>();
      final mine = rows
          .map((e) =>
              TeamJoinRequest.fromSupabaseRow(Map<String, dynamic>.from(e)))
          .where((r) => r.userId == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mine.isEmpty) return null;
      return mine.first;
    });
  }

  @override
  Future<String> insertJoinRequest(TeamJoinRequest request) async {
    final res = await _c
        .from('team_join_requests')
        .insert(request.toSupabaseInsert())
        .select('id')
        .single();
    return res['id'] as String;
  }

  @override
  Future<bool> hasPendingJoinRequest(String teamId, String userId) async {
    final row = await _c
        .from('team_join_requests')
        .select('id')
        .eq('team_id', teamId)
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    return row != null;
  }

  @override
  Future<void> respondToJoinRequestRpc({
    required String requestId,
    required bool accept,
  }) async {
    await _c.rpc(
      'team_join_respond',
      params: {
        'p_request_id': requestId,
        'p_accept': accept,
      },
    );
  }

  @override
  Stream<List<TeamMatchRequest>> watchPendingMatchRequestsForTeam(
      String teamId) {
    return _c
        .from('team_match_requests')
        .stream(primaryKey: const ['id'])
        .eq('team_id', teamId)
        .map((raw) {
      final rows = (raw as List).cast<Map>();
      return rows
          .map((e) =>
              TeamMatchRequest.fromSupabaseRow(Map<String, dynamic>.from(e)))
          .where((r) => r.status == TeamMatchRequestStatus.pending)
          .toList();
    });
  }

  @override
  Future<void> insertMatchRequest(TeamMatchRequest request) async {
    await _c.from('team_match_requests').insert(request.toSupabaseInsert());
  }

  @override
  Future<void> updateMatchRequestStatus({
    required String requestId,
    required bool accepted,
  }) async {
    await _c.from('team_match_requests').update({
      'status': accepted ? 'accepted' : 'declined',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  @override
  Future<List<AppTeam>> searchTeamsLocalFilter(String query, {int limit = 10}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    final rows =
        await _c.from('teams').select().eq('is_public', true).limit(300);
    final matches = <AppTeam>[];
    for (final r in (rows as List).cast<Map>()) {
      final team = AppTeam.fromSupabaseRow(Map<String, dynamic>.from(r));
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

    dynamic request = _c.from('profiles').select(
          'id, display_name, name, surname, email, avatar_url, position',
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
      final displayNameRaw =
          (m['display_name'] ?? m['name'] ?? m['surname'] ?? '').toString().trim();
      final firstName = (m['name'] ?? '').toString().trim();
      final lastName = (m['surname'] ?? '').toString().trim();
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
    await _c.rpc('team_leave', params: {'p_team_id': teamId});
  }

  @override
  Future<void> insertTeamActivity({
    required String type,
    required String teamId,
    required String teamName,
    required String userId,
    required String userName,
  }) async {
    try {
      await _c.from('team_activity').insert({
        'type': type,
        'team_id': teamId,
        'team_name': teamName,
        'user_id': userId,
        'user_name': userName,
      });
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileForDisplay(String userId) async {
    final row = await _c
        .from('profiles')
        .select('display_name, name, surname, avatar_url')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final dn = (m['display_name'] ?? '').toString().trim();
    final n = (m['name'] ?? '').toString().trim();
    final s = (m['surname'] ?? '').toString().trim();
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
        .from('profiles')
        .select('display_name, name, surname')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final m = Map<String, dynamic>.from(row);
    final dn = (m['display_name'] ?? '').toString().trim();
    if (dn.isNotEmpty) return dn;
    final n = (m['name'] ?? '').toString().trim();
    final s = (m['surname'] ?? '').toString().trim();
    final combined = '$n $s'.trim();
    return combined.isNotEmpty ? combined : null;
  }

  @override
  Future<void> addViceCaptain(String teamId, String userId) async {
    final row = await _c
        .from('teams')
        .select('vice_captain_ids')
        .eq('id', teamId)
        .single();
    final cur = List<String>.from(
      (row['vice_captain_ids'] as List?)?.map((e) => e.toString()) ?? const [],
    );
    if (!cur.contains(userId)) cur.add(userId);
    await _c.from('teams').update({
      'vice_captain_ids': cur,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', teamId);
  }

  @override
  Future<void> removeViceCaptain(String teamId, String userId) async {
    final row = await _c
        .from('teams')
        .select('vice_captain_ids')
        .eq('id', teamId)
        .single();
    final cur = List<String>.from(
      (row['vice_captain_ids'] as List?)?.map((e) => e.toString()) ?? const [],
    )..remove(userId);
    await _c.from('teams').update({
      'vice_captain_ids': cur,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', teamId);
  }

  @override
  Future<void> applyStandingsAfterTeamMatch({
    required Match match,
    required int teamAScore,
    required int teamBScore,
    required Map<String, int> goalsByPlayer,
  }) async {
    if (match.teamAId == null || match.teamBId == null) return;
    final aRow =
        await _c.from('teams').select().eq('id', match.teamAId!).maybeSingle();
    final bRow =
        await _c.from('teams').select().eq('id', match.teamBId!).maybeSingle();
    if (aRow == null || bRow == null) return;
    final teamA = AppTeam.fromSupabaseRow(Map<String, dynamic>.from(aRow));
    final teamB = AppTeam.fromSupabaseRow(Map<String, dynamic>.from(bRow));
    final rosterA =
        match.teamRosters['teamA'] ?? match.teamA?.playerIds ?? const [];
    final rosterB =
        match.teamRosters['teamB'] ?? match.teamB?.playerIds ?? const [];
    final resultA = teamAScore.compareTo(teamBScore);
    final playedAt = DateTime.now().toUtc().toIso8601String();
    final summaryA = <String, dynamic>{
      'matchId': match.id,
      'opponentTeamId': match.teamBId,
      'opponentName': teamB.name,
      'score': '$teamAScore:$teamBScore',
      'result': resultA > 0
          ? 'win'
          : resultA < 0
              ? 'loss'
              : 'draw',
      'playedAt': playedAt,
    };
    final summaryB = <String, dynamic>{
      'matchId': match.id,
      'opponentTeamId': match.teamAId,
      'opponentName': teamA.name,
      'score': '$teamBScore:$teamAScore',
      'result': resultA < 0
          ? 'win'
          : resultA > 0
              ? 'loss'
              : 'draw',
      'playedAt': playedAt,
    };
    final recentA = [summaryA, ...teamA.recentMatches];
    final recentB = [summaryB, ...teamB.recentMatches];
    final aPlayerGoals = Map<String, int>.from(teamA.playerGoals);
    final bPlayerGoals = Map<String, int>.from(teamB.playerGoals);
    for (final uid in rosterA) {
      final goals = goalsByPlayer[uid] ?? 0;
      if (goals > 0) {
        aPlayerGoals[uid] = (aPlayerGoals[uid] ?? 0) + goals;
      }
    }
    for (final uid in rosterB) {
      final goals = goalsByPlayer[uid] ?? 0;
      if (goals > 0) {
        bPlayerGoals[uid] = (bPlayerGoals[uid] ?? 0) + goals;
      }
    }
    final naWins = teamA.wins + (resultA > 0 ? 1 : 0);
    final naLosses = teamA.losses + (resultA < 0 ? 1 : 0);
    final naDraws = teamA.draws + (resultA == 0 ? 1 : 0);
    final nbWins = teamB.wins + (resultA < 0 ? 1 : 0);
    final nbLosses = teamB.losses + (resultA > 0 ? 1 : 0);
    final nbDraws = teamB.draws + (resultA == 0 ? 1 : 0);
    try {
      await _c.rpc(
        'teams_set_standings_after_match',
        params: {
          'p_team_a_id': match.teamAId,
          'p_team_a_wins': naWins,
          'p_team_a_losses': naLosses,
          'p_team_a_draws': naDraws,
          'p_team_a_goals_for': teamA.goalsFor + teamAScore,
          'p_team_a_goals_against': teamA.goalsAgainst + teamBScore,
          'p_team_a_player_goals': aPlayerGoals,
          'p_team_a_recent': recentA.take(5).toList(),
          'p_team_b_id': match.teamBId,
          'p_team_b_wins': nbWins,
          'p_team_b_losses': nbLosses,
          'p_team_b_draws': nbDraws,
          'p_team_b_goals_for': teamB.goalsFor + teamBScore,
          'p_team_b_goals_against': teamB.goalsAgainst + teamAScore,
          'p_team_b_player_goals': bPlayerGoals,
          'p_team_b_recent': recentB.take(5).toList(),
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('Warning updating teams standings: $e');
    }
  }
}
