import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/city_catalog.dart';

import '../../../teams/data/models/app_team.dart';
import '../models/match.dart';
import '../supabase/match_legacy_remote_mapper.dart';
import '../../../../core/auth/app_auth.dart';

class MatchService {
  final SupabaseClient _sb = Supabase.instance.client;

  Stream<List<Match>> getAvailableMatches() {
    return _sb.from('matches').stream(primaryKey: ['id']).asyncMap((rows) async {
      final out = <Match>[];
      for (final raw in rows as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        if ((row['status'] ?? '') != 'open') continue;
        final id = (row['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final m = await _loadMatch(id);
        if (m == null) continue;
        if (m.isUnplayedByTimeout) {
          await _markAsUnplayedTimedOut(id);
          continue;
        }
        out.add(m);
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    });
  }

  Future<void> _markAsUnplayedTimedOut(String matchId) async {
    try {
      await _sb.from('matches').update({
        'status': 'cancelled',
        'cancellation_reason': 'timeout_24h_no_start',
      }).eq('id', matchId);
    } catch (_) {
      // best-effort
    }
  }

  Stream<List<Match>> getUserMatches(String userId) {
    return _sb
        .from('match_participants')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      final ids = (rows as List<dynamic>)
          .where((raw) => (raw as Map<String, dynamic>)['user_id'] == userId)
          .map((raw) => (raw as Map<String, dynamic>)['match_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final out = <Match>[];
      for (final id in ids) {
        final m = await _loadMatch(id);
        if (m != null) out.add(m);
      }
      out.sort((a, b) => b.date.compareTo(a.date));
      return out;
    });
  }

  /// DB `matches.level` allows `'pro'`, not enum name `'professional'`.
  static String _levelToSupabase(MatchLevel level) {
    switch (level) {
      case MatchLevel.professional:
        return 'pro';
      case MatchLevel.beginner:
        return 'beginner';
      case MatchLevel.intermediate:
        return 'intermediate';
      case MatchLevel.advanced:
        return 'advanced';
    }
  }

  /// DB `matches.status` uses `in_progress` / snake_case, not [MatchStatus.inProgress.name] (`inProgress`).
  static String _matchStatusToSupabase(MatchStatus s) {
    switch (s) {
      case MatchStatus.open:
        return 'open';
      case MatchStatus.full:
        return 'full';
      case MatchStatus.inProgress:
        return 'in_progress';
      case MatchStatus.finished:
        return 'finished';
      case MatchStatus.cancelled:
        return 'cancelled';
    }
  }

  Future<String> createMatch(Match match) async {
    // Same client as the Supabase request so JWT matches `auth.uid()` in RLS.
    final sessionUser = _sb.auth.currentUser;
    final uid = sessionUser?.id;
    if (uid == null) {
      throw StateError('createMatch: no Supabase session');
    }

    final inserted = await _sb
        .from('matches')
        .insert({
          'organizer_id': uid,
          'title': match.title,
          'description': match.description,
          'scheduled_at': match.date.toUtc().toIso8601String(),
          'location': match.location,
          'city': CityCatalog.toEnglishStorageKey(match.city) ?? match.city,
          'latitude': match.coordinates?.latitude,
          'longitude': match.coordinates?.longitude,
          'max_players': match.maxPlayers,
          'participation_cost': match.cost,
          'level': _levelToSupabase(match.level),
          'auto_balance': match.autoBalance,
          'is_private': match.isPrivate,
          'is_team_match': match.isTeamMatch,
          'status': _matchStatusToSupabase(match.status),
        })
        .select('id')
        .single();
    final matchId = inserted['id'].toString();

    await _sb.from('match_participants').insert({
      'match_id': matchId,
      'user_id': uid,
      'status': 'accepted',
      'joined_at': DateTime.now().toUtc().toIso8601String(),
      'responded_at': DateTime.now().toUtc().toIso8601String(),
    });

    if (match.isPrivate && match.invitedFriends.isNotEmpty) {
      for (final friendId in match.invitedFriends) {
        await _sb.from('match_invites').upsert(
          {
            'match_id': matchId,
            'user_id': friendId,
            'invited_by': uid,
            'status': 'pending',
          },
          onConflict: 'match_id,user_id',
        );
      }
    }
    return matchId;
  }

  Future<bool> joinMatch(String matchId, String userId) async {
    return applyForMatch(matchId, userId);
  }

  Future<bool> leaveMatch(String matchId, String userId) async {
    try {
      await _sb
          .from('match_participants')
          .update({
            'status': 'left',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('match_id', matchId)
          .eq('user_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyForMatch(String matchId, String userId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      if (m.isUnplayedByTimeout || m.isTeamMatch) return false;
      if (m.isPrivate && !m.invitedFriends.contains(userId)) return false;
      if (m.participants.contains(userId) ||
          m.pendingApplications.contains(userId) ||
          m.rejectedApplications.contains(userId)) {
        return false;
      }

      await _sb.from('match_participants').upsert({
        'match_id': matchId,
        'user_id': userId,
        'status': 'pending_application',
        'applied_at': DateTime.now().toUtc().toIso8601String(),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> acceptApplication(String matchId, String userId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;
      if (!m.pendingApplications.contains(userId)) return false;
      if (m.currentPlayers >= m.maxPlayers) return false;

      await _sb
          .from('match_participants')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
            'joined_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('match_id', matchId)
          .eq('user_id', userId);

      final refreshed = await _loadMatch(matchId);
      if (refreshed != null && refreshed.currentPlayers >= refreshed.maxPlayers) {
        await _sb.from('matches').update({'status': 'full'}).eq('id', matchId);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectApplication(String matchId, String userId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;
      if (!m.pendingApplications.contains(userId)) return false;

      await _sb
          .from('match_participants')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('match_id', matchId)
          .eq('user_id', userId);

      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<String>> getMatchApplications(String matchId) {
    return _sb
        .from('match_participants')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      return (rows as List<dynamic>)
          .where((raw) =>
              (raw as Map<String, dynamic>)['match_id'] == matchId &&
              raw['status'] == 'pending_application')
          .map((raw) => (raw as Map<String, dynamic>)['user_id'].toString())
          .toList(growable: false);
    });
  }

  Future<bool> autoBalanceTeams(String matchId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null || m.participants.length < 2 || m.hasTeams) return false;
      final sorted = List<String>.from(m.participants);
      final teamAPlayers = <String>[];
      final teamBPlayers = <String>[];
      for (int i = 0; i < sorted.length; i++) {
        (i.isEven ? teamAPlayers : teamBPlayers).add(sorted[i]);
      }
      return updateTeams(matchId, teamAPlayers, teamBPlayers);
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTeams(
    String matchId,
    List<String> teamAPlayers,
    List<String> teamBPlayers,
  ) async {
    try {
      final existing = await _sb
          .from('match_teams')
          .select('id,team_slot')
          .eq('match_id', matchId);
      String? teamAId;
      String? teamBId;
      for (final raw in existing as List<dynamic>) {
        final row = raw as Map<String, dynamic>;
        if ((row['team_slot'] as int?) == 1) {
          teamAId = row['id'].toString();
        } else if ((row['team_slot'] as int?) == 2) {
          teamBId = row['id'].toString();
        }
      }
      teamAId ??= await _createMatchTeam(matchId, 1, 'Команда A');
      teamBId ??= await _createMatchTeam(matchId, 2, 'Команда B');

      await _sb.from('match_team_rosters').delete().eq('match_team_id', teamAId);
      await _sb.from('match_team_rosters').delete().eq('match_team_id', teamBId);
      for (final uid in teamAPlayers) {
        await _sb.from('match_team_rosters').insert({
          'match_team_id': teamAId,
          'player_id': uid,
          'status': 'confirmed',
        });
      }
      for (final uid in teamBPlayers) {
        await _sb.from('match_team_rosters').insert({
          'match_team_id': teamBId,
          'player_id': uid,
          'status': 'confirmed',
        });
      }
      await _sb.from('matches').update({'status': 'full'}).eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTeamsFlexible(String matchId, List<List<String>> teams) async {
    try {
      final existing = await _sb.from('match_teams').select('id').eq('match_id', matchId);
      for (final row in existing as List<dynamic>) {
        await _sb.from('match_team_rosters').delete().eq('match_team_id', row['id']);
      }
      await _sb.from('match_teams').delete().eq('match_id', matchId);

      for (var i = 0; i < teams.length; i++) {
        final teamId = await _createMatchTeam(matchId, i + 1, MatchUtils.generateTeamNames(teams.length)[i]);
        for (final uid in teams[i]) {
          await _sb.from('match_team_rosters').insert({
            'match_team_id': teamId,
            'player_id': uid,
            'status': 'confirmed',
          });
        }
      }
      await ensureFixtures(matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFixtures(String matchId) async {
    final rows = await _sb
        .from('match_fixtures')
        .select('id, status, home_score, away_score, home_match_team_id, away_match_team_id, match_teams!home_match_team_id(display_name), away:match_teams!away_match_team_id(display_name)')
        .eq('match_id', matchId);
    return (rows as List<dynamic>).map((raw) {
      final row = raw as Map<String, dynamic>;
      return <String, dynamic>{
        'id': row['id'],
        'status': row['status'],
        'scoreA': row['home_score'],
        'scoreB': row['away_score'],
        'teamAName': ((row['match_teams'] as Map?)?['display_name'] ?? 'Team A').toString(),
        'teamBName': ((row['away'] as Map?)?['display_name'] ?? 'Team B').toString(),
      };
    }).toList();
  }

  Future<bool> finishGame(String matchId, String fixtureId, int scoreA, int scoreB) async {
    try {
      await _sb.from('match_fixtures').update({
        'home_score': scoreA,
        'away_score': scoreB,
        'status': 'finished',
        'finished_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', fixtureId);

      final all = await _sb.from('match_fixtures').select('status').eq('match_id', matchId);
      final allFinished = (all as List<dynamic>).every(
        (raw) => (raw as Map<String, dynamic>)['status'] == 'finished',
      );
      if (allFinished) {
        await _sb.from('matches').update({
          'status': 'finished',
          'finished_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', matchId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> promptFinishGame(
    BuildContext context,
    String matchId,
    int fixtureIndex,
    String aName,
    String bName,
  ) async {
    final fixtures = await getFixtures(matchId);
    if (fixtureIndex < 0 || fixtureIndex >= fixtures.length) return;
    final f = fixtures[fixtureIndex];
    final ctrlA = TextEditingController();
    final ctrlB = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr('match_result_title', args: [aName, bName])),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrlA,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('goals_for_team', args: [aName])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrlB,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('goals_for_team', args: [bName])),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('save'))),
          ],
        );
      },
    );
    if (ok == true) {
      final a = int.tryParse(ctrlA.text) ?? 0;
      final b = int.tryParse(ctrlB.text) ?? 0;
      await finishGame(matchId, f['id'] as String, a, b);
    }
  }

  Future<void> ensureFixtures(String matchId) async {
    final teams = await _sb
        .from('match_teams')
        .select('id,team_slot,display_name')
        .eq('match_id', matchId)
        .order('team_slot');
    final t = (teams as List<dynamic>).cast<Map<String, dynamic>>();
    if (t.length <= 2) return;
    final existing = await _sb.from('match_fixtures').select('id').eq('match_id', matchId).limit(1);
    if ((existing as List).isNotEmpty) return;

    for (var i = 0; i < t.length; i++) {
      for (var j = i + 1; j < t.length; j++) {
        await _sb.from('match_fixtures').insert({
          'match_id': matchId,
          'home_match_team_id': t[i]['id'],
          'away_match_team_id': t[j]['id'],
          'status': 'scheduled',
        });
      }
    }
  }

  Future<bool> startMatch(String matchId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;
      if (m.isInProgress || m.participants.length < 2) return false;

      await _sb.from('matches').update({
        'status': 'in_progress',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> finishMatch(
    String matchId,
    MatchResult result,
    int teamAScore,
    int teamBScore, {
    Map<String, int> goalsByPlayer = const {},
  }) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;

      await _sb.from('matches').update({
        'status': 'finished',
        'finished_at': DateTime.now().toUtc().toIso8601String(),
        'cancellation_reason': '${result.name}:$teamAScore:$teamBScore',
      }).eq('id', matchId);

      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Match>> getMatchesForRating(String userId) {
    return _sb
        .from('match_participants')
        .stream(primaryKey: ['id'])
        .asyncMap((rows) async {
      final ids = (rows as List<dynamic>)
          .where((raw) =>
              (raw as Map<String, dynamic>)['user_id'] == userId &&
              raw['status'] == 'accepted')
          .map((raw) => (raw as Map<String, dynamic>)['match_id'].toString())
          .toSet();
      final out = <Match>[];
      for (final id in ids) {
        final m = await _loadMatch(id);
        if (m != null && m.status == MatchStatus.finished) out.add(m);
      }
      out.sort((a, b) => b.date.compareTo(a.date));
      return out;
    });
  }

  Future<bool> cancelMatch(String matchId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;
      await _sb.from('matches').update({
        'status': 'cancelled',
        'cancellation_reason': 'cancelled_by_organizer',
      }).eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMatch(String matchId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;
      if (m.isInProgress || m.isFinished) return false;
      await _sb.from('matches').delete().eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveMultiTeamResults(String matchId, List<Map<String, int>> stats) async {
    try {
      await _sb.from('matches').update({
        'cancellation_reason': 'multi_team_stats:${stats.length}',
      }).eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setTeamRoster({
    required String matchId,
    required String teamKey,
    required AppTeam team,
    required List<String> playerIds,
  }) async {
    final slot = teamKey == 'teamA' ? 1 : 2;
    final matchTeamId = await _ensureMatchTeam(matchId, slot, team.name);
    await _sb.from('match_team_rosters').delete().eq('match_team_id', matchTeamId);
    for (final playerId in playerIds) {
      await _sb.from('match_team_rosters').insert({
        'match_team_id': matchTeamId,
        'player_id': playerId,
        'status': 'pending',
      });
    }
  }

  Future<void> respondToRosterInvite({
    required String matchId,
    required String teamKey,
    required bool accept,
  }) async {
    final uid = AppAuth.currentUserId;
    if (uid == null) throw Exception('Потрібна авторизація');
    final slot = teamKey == 'teamA' ? 1 : 2;
    final teamId = await _ensureMatchTeam(matchId, slot, slot == 1 ? 'Команда A' : 'Команда B');
    await _sb.from('match_team_rosters').update({
      'status': accept ? 'confirmed' : 'declined',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('match_team_id', teamId).eq('player_id', uid);
  }

  Future<void> updateCoverPhoto({
    required String matchId,
    required String photoUrl,
  }) async {
    // Legacy field is not in normalized schema; keep method as no-op.
    return;
  }

  Future<Match?> _loadMatch(String matchId) async {
    final legacy = await MatchLegacyRemoteMapper.load(_sb, matchId);
    if (legacy == null) return null;
    return Match.fromLegacyMap(matchId, legacy);
  }

  Future<String> _createMatchTeam(String matchId, int slot, String name) async {
    final inserted = await _sb
        .from('match_teams')
        .insert({
          'match_id': matchId,
          'team_slot': slot,
          'display_name': name,
        })
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  Future<String> _ensureMatchTeam(String matchId, int slot, String name) async {
    final existing = await _sb
        .from('match_teams')
        .select('id')
        .eq('match_id', matchId)
        .eq('team_slot', slot)
        .maybeSingle();
    if (existing != null) return existing['id'].toString();
    return _createMatchTeam(matchId, slot, name);
  }
}
