import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/city_catalog.dart';

import '../../../teams/data/models/app_team.dart';
import '../models/match.dart';
import '../supabase/match_legacy_remote_mapper.dart';
import '../../../../core/auth/app_auth.dart';

/// Builds the parameter map for the `public.create_team_match` RPC.
///
/// Pure function so the SQL contract from
/// `20260508160000_create_team_match_rpc.sql` can be locked in by unit
/// tests. The RPC validates each field server-side, but keeping the
/// trim/dedup logic here keeps surprising input out of Postgres logs and
/// matches the pattern already used by the team-match acceptance RPCs.
@visibleForTesting
Map<String, dynamic> buildCreateTeamMatchRpcParams({
  required String title,
  required String description,
  required DateTime scheduledAt,
  required String location,
  required String city,
  double? latitude,
  double? longitude,
  required int maxPlayers,
  required double cost,
  required String level,
  required bool isPrivate,
  required String hostTeamId,
  List<String> hostRoster = const <String>[],
  String? opponentTeamId,
  List<String> opponentProposedRoster = const <String>[],
}) {
  List<String> dedup(List<String> input) {
    final out = <String>{};
    for (final raw in input) {
      final v = raw.trim();
      if (v.isNotEmpty) out.add(v);
    }
    return out.toList(growable: false);
  }

  final cleanedHost = dedup(hostRoster);
  final cleanedOpp = dedup(opponentProposedRoster);
  final trimmedTitle = title.trim();
  final trimmedDescription = description.trim();
  final trimmedLocation = location.trim();
  final trimmedCity = city.trim();
  final trimmedOpponent = opponentTeamId?.trim();

  return <String, dynamic>{
    'p_title': trimmedTitle,
    'p_description': trimmedDescription,
    'p_scheduled_at': scheduledAt.toUtc().toIso8601String(),
    'p_location': trimmedLocation,
    'p_city': trimmedCity,
    'p_latitude': latitude,
    'p_longitude': longitude,
    'p_max_players': maxPlayers,
    'p_participation_cost': cost,
    'p_level': level,
    'p_is_private': isPrivate,
    'p_host_team_id': hostTeamId,
    'p_host_roster': cleanedHost,
    if (trimmedOpponent != null && trimmedOpponent.isNotEmpty)
      'p_opponent_team_id': trimmedOpponent,
    'p_opponent_proposed_roster': cleanedOpp,
  };
}

class MatchService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<Map<String, double>> _loadProfileRatings(List<String> userIds) async {
    final clean = userIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (clean.isEmpty) return const <String, double>{};
    const chunkSize = 100;
    final out = <String, double>{};
    for (var i = 0; i < clean.length; i += chunkSize) {
      final chunk = clean.sublist(
        i,
        i + chunkSize > clean.length ? clean.length : i + chunkSize,
      );
      final rows = await _sb
          .from('profiles')
          .select('id,overall_rating')
          .inFilter('id', chunk);
      for (final raw in rows as List<dynamic>) {
        final m = Map<String, dynamic>.from(raw as Map);
        final id = m['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final r = (m['overall_rating'] as num?)?.toDouble() ?? 0.0;
        out[id] = r;
      }
    }
    return out;
  }

  double _sumTeamTotalRating(
    List<String> playerIds,
    Map<String, double> ratingsById,
  ) {
    var sum = 0.0;
    for (final id in playerIds) {
      sum += ratingsById[id] ?? 0.0;
    }
    return sum;
  }

  Future<List<Match>> fetchAvailableMatches() async {
    final rows = await _sb
        .from('matches')
        .select('id, status')
        .eq('status', 'open');
    final openIds = <String>[];
    final seen = <String>{};
    for (final raw in rows as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty || !seen.add(id)) continue;
      openIds.add(id);
    }
    if (openIds.isEmpty) return <Match>[];

    final legacyMaps = await MatchLegacyRemoteMapper.loadLegacyMapsBatch(
      _sb,
      openIds,
    );
    final out = <Match>[];
    for (final id in openIds) {
      final legacy = legacyMaps[id];
      if (legacy == null) continue;
      final m = Match.fromLegacyMap(id, legacy);
      if (m.isUnplayedByTimeout) {
        await _markAsUnplayedTimedOut(id);
        continue;
      }
      out.add(m);
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  Future<void> _markAsUnplayedTimedOut(String matchId) async {
    try {
      await _sb
          .from('matches')
          .update({
            'status': 'cancelled',
            'cancellation_reason': 'timeout_24h_no_start',
          })
          .eq('id', matchId);
    } catch (_) {
      // best-effort
    }
  }

  Future<List<Match>> fetchUserMatches(String userId) async {
    final participantRows = await _sb
        .from('match_participants')
        .select('match_id')
        .eq('user_id', userId);
    final fromParticipants = (participantRows as List<dynamic>)
        .map(
          (raw) => (raw as Map<String, dynamic>)['match_id']?.toString() ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toSet();

    final fromRosters = await _matchIdsFromUserTeamRosters(userId);

    final ids = {...fromParticipants, ...fromRosters}.toList();
    if (ids.isEmpty) return <Match>[];

    final legacyMaps = await MatchLegacyRemoteMapper.loadLegacyMapsBatch(
      _sb,
      ids,
    );
    final out = <Match>[];
    for (final id in ids) {
      final legacy = legacyMaps[id];
      if (legacy == null) continue;
      out.add(Match.fromLegacyMap(id, legacy));
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  Future<Set<String>> _matchIdsFromUserTeamRosters(String userId) async {
    try {
      final rows = await _sb
          .from('match_team_rosters')
          .select('status, match_teams(match_id)')
          .eq('player_id', userId);
      final ids = <String>{};
      for (final raw in rows as List<dynamic>) {
        final r = raw as Map<String, dynamic>;
        final st = (r['status'] ?? '').toString().trim().toLowerCase();
        if (st == 'declined') continue;
        final nested = r['match_teams'];
        String? mid;
        if (nested is Map<String, dynamic>) {
          mid = nested['match_id']?.toString();
        } else if (nested is List && nested.isNotEmpty) {
          final first = nested.first;
          if (first is Map<String, dynamic>) {
            mid = first['match_id']?.toString();
          }
        }
        if (mid != null && mid.isNotEmpty) ids.add(mid);
      }
      return ids;
    } catch (_) {
      return {};
    }
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
          'scheduled_at': match.scheduledDateTime.toUtc().toIso8601String(),
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
        await _sb.from('match_invites').upsert({
          'match_id': matchId,
          'user_id': friendId,
          'invited_by': uid,
          'status': 'pending',
        }, onConflict: 'match_id,user_id');
      }
    }
    return matchId;
  }

  /// Atomic team-match creation. Delegates to the SECURITY DEFINER RPC
  /// `public.create_team_match` so matches + slot 1 + host roster +
  /// team_match_requests commit together. RLS misalignments and
  /// partial-success retries can no longer leave orphan matches.
  Future<String> createTeamMatch({
    required String title,
    required String description,
    required DateTime scheduledAt,
    required String location,
    required String city,
    double? latitude,
    double? longitude,
    required int maxPlayers,
    required double cost,
    required MatchLevel level,
    required bool isPrivate,
    required String hostTeamId,
    List<String> hostRoster = const <String>[],
    String? opponentTeamId,
    List<String> opponentProposedRoster = const <String>[],
  }) async {
    final sessionUser = _sb.auth.currentUser;
    if (sessionUser == null) {
      throw StateError('createTeamMatch: no Supabase session');
    }

    final response = await _sb.rpc(
      'create_team_match',
      params: buildCreateTeamMatchRpcParams(
        title: title,
        description: description,
        scheduledAt: scheduledAt,
        location: location,
        city: CityCatalog.toEnglishStorageKey(city) ?? city,
        latitude: latitude,
        longitude: longitude,
        maxPlayers: maxPlayers,
        cost: cost,
        level: _levelToSupabase(level),
        isPrivate: isPrivate,
        hostTeamId: hostTeamId,
        hostRoster: hostRoster,
        opponentTeamId: opponentTeamId,
        opponentProposedRoster: opponentProposedRoster,
      ),
    );

    final payload = response is Map<String, dynamic>
        ? response
        : (response is Map ? Map<String, dynamic>.from(response) : null);
    final matchId = payload?['matchId']?.toString();
    if (matchId == null || matchId.isEmpty) {
      throw StateError('create_team_match returned no matchId');
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
      if (refreshed != null &&
          refreshed.currentPlayers >= refreshed.maxPlayers) {
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
    return _sb.from('match_participants').stream(primaryKey: ['id']).asyncMap((
      rows,
    ) async {
      return (rows as List<dynamic>)
          .where(
            (raw) =>
                (raw as Map<String, dynamic>)['match_id'] == matchId &&
                raw['status'] == 'pending_application',
          )
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
      teamAId ??= await _createMatchTeam(
        matchId,
        1,
        tr('match_default_team_a'),
      );
      teamBId ??= await _createMatchTeam(
        matchId,
        2,
        tr('match_default_team_b'),
      );

      await _sb
          .from('match_team_rosters')
          .delete()
          .eq('match_team_id', teamAId);
      await _sb
          .from('match_team_rosters')
          .delete()
          .eq('match_team_id', teamBId);
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
      final ratingsById = await _loadProfileRatings([
        ...teamAPlayers,
        ...teamBPlayers,
      ]);
      await _sb
          .from('match_teams')
          .update({
            'team_total_rating': _sumTeamTotalRating(teamAPlayers, ratingsById),
          })
          .eq('id', teamAId);
      await _sb
          .from('match_teams')
          .update({
            'team_total_rating': _sumTeamTotalRating(teamBPlayers, ratingsById),
          })
          .eq('id', teamBId);
      await _sb
          .from('matches')
          .update({
            'status': 'full',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTeamsFlexible(
    String matchId,
    List<List<String>> teams,
  ) async {
    try {
      final existing = await _sb
          .from('match_teams')
          .select('id')
          .eq('match_id', matchId);
      for (final row in existing as List<dynamic>) {
        await _sb
            .from('match_team_rosters')
            .delete()
            .eq('match_team_id', row['id']);
      }
      await _sb.from('match_teams').delete().eq('match_id', matchId);

      final allPlayers = teams.expand((t) => t).toList();
      final ratingsById = await _loadProfileRatings(allPlayers);

      for (var i = 0; i < teams.length; i++) {
        final teamPlayers = teams[i];
        final teamId = await _createMatchTeam(
          matchId,
          i + 1,
          MatchUtils.generateTeamNames(teams.length)[i],
          totalRating: _sumTeamTotalRating(teamPlayers, ratingsById),
        );
        for (final uid in teamPlayers) {
          await _sb.from('match_team_rosters').insert({
            'match_team_id': teamId,
            'player_id': uid,
            'status': 'confirmed',
          });
        }
      }
      await ensureFixtures(matchId);
      await _sb
          .from('matches')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', matchId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFixtures(String matchId) async {
    final rows = await _sb
        .from('match_fixtures')
        .select(
          'id, status, home_score, away_score, home_match_team_id, away_match_team_id, match_teams!home_match_team_id(display_name), away:match_teams!away_match_team_id(display_name)',
        )
        .eq('match_id', matchId);
    return (rows as List<dynamic>).map((raw) {
      final row = raw as Map<String, dynamic>;
      return <String, dynamic>{
        'id': row['id'],
        'status': row['status'],
        'scoreA': row['home_score'],
        'scoreB': row['away_score'],
        'teamAName':
            ((row['match_teams'] as Map?)?['display_name'] ??
                    tr('match_default_team_a'))
                .toString(),
        'teamBName':
            ((row['away'] as Map?)?['display_name'] ??
                    tr('match_default_team_b'))
                .toString(),
      };
    }).toList();
  }

  Future<bool> finishGame(
    String matchId,
    String fixtureId,
    int scoreA,
    int scoreB,
  ) async {
    try {
      await _sb
          .from('match_fixtures')
          .update({
            'home_score': scoreA,
            'away_score': scoreB,
            'status': 'finished',
            'finished_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', fixtureId);

      final all = await _sb
          .from('match_fixtures')
          .select('status')
          .eq('match_id', matchId);
      final allFinished = (all as List<dynamic>).every(
        (raw) => (raw as Map<String, dynamic>)['status'] == 'finished',
      );
      if (allFinished) {
        await _sb
            .from('matches')
            .update({
              'status': 'finished',
              'finished_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', matchId);
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
                  decoration: InputDecoration(
                    labelText: tr('goals_for_team', args: [aName]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: ctrlB,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('goals_for_team', args: [bName]),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('save')),
            ),
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
    final existing = await _sb
        .from('match_fixtures')
        .select('id')
        .eq('match_id', matchId)
        .limit(1);
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
      if (m.isInProgress) return false;
      // Team matches should not require manual team formation/participant count
      // to start. Keep that requirement only for non-team matches.
      if (!m.isTeamMatch && m.participants.length < 2) return false;

      await _sb
          .from('matches')
          .update({
            'status': 'in_progress',
            'started_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', matchId);
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

      final now = DateTime.now().toUtc().toIso8601String();

      await _sb
          .from('match_participant_goals')
          .delete()
          .eq('match_id', matchId);
      if (goalsByPlayer.isNotEmpty) {
        final rows = goalsByPlayer.entries
            .map(
              (e) => <String, dynamic>{
                'match_id': matchId,
                'player_id': e.key,
                'goals': e.value,
              },
            )
            .toList();
        await _sb.from('match_participant_goals').insert(rows);
      }

      await _sb
          .from('matches')
          .update({
            'status': 'finished',
            'finished_at': now,
            'updated_at': now,
            'cancellation_reason': '${result.name}:$teamAScore:$teamBScore',
          })
          .eq('id', matchId);

      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Match>> getMatchesForRating(String userId) {
    Future<List<Match>> loadFinishedParticipatedMatches() async {
      final participantRows = await _sb
          .from('match_participants')
          .select('match_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');
      final fromParticipants = (participantRows as List<dynamic>)
          .map(
            (raw) =>
                (raw as Map<String, dynamic>)['match_id']?.toString() ?? '',
          )
          .where((id) => id.isNotEmpty)
          .toSet();

      final fromRosters = await _matchIdsFromUserTeamRosters(userId);

      final ids = {...fromParticipants, ...fromRosters}.toList();
      if (ids.isEmpty) return <Match>[];

      final legacyMaps = await MatchLegacyRemoteMapper.loadLegacyMapsBatch(
        _sb,
        ids,
      );
      final out = <Match>[];
      for (final id in ids) {
        final legacy = legacyMaps[id];
        if (legacy == null) continue;
        final m = Match.fromLegacyMap(id, legacy);
        if (m.status == MatchStatus.finished) out.add(m);
      }
      out.sort((a, b) => b.date.compareTo(a.date));
      return out;
    }

    late StreamController<List<Match>> outCtrl;
    StreamSubscription<List<Map<String, dynamic>>>? subParticipants;
    StreamSubscription<List<Map<String, dynamic>>>? subTeamRosters;
    StreamSubscription<List<Map<String, dynamic>>>? subMatches;

    outCtrl = StreamController<List<Match>>(
      onListen: () {
        scheduleMicrotask(() async {
          Future<void> emit() async {
            try {
              outCtrl.add(await loadFinishedParticipatedMatches());
            } catch (e, st) {
              outCtrl.addError(e, st);
            }
          }

          await emit();
          subParticipants = _sb
              .from('match_participants')
              .stream(primaryKey: ['id'])
              .listen((_) => emit());
          subTeamRosters = _sb
              .from('match_team_rosters')
              .stream(primaryKey: ['match_team_id', 'player_id'])
              .listen((_) => emit());
          subMatches = _sb
              .from('matches')
              .stream(primaryKey: ['id'])
              .listen((_) => emit());
        });
      },
      onCancel: () async {
        await subParticipants?.cancel();
        await subTeamRosters?.cancel();
        await subMatches?.cancel();
        subParticipants = null;
        subTeamRosters = null;
        subMatches = null;
      },
    );

    return outCtrl.stream;
  }

  Future<bool> cancelMatch(String matchId) async {
    try {
      final m = await _loadMatch(matchId);
      if (m == null) return false;
      final currentUserId = AppAuth.currentUserId;
      if (currentUserId == null || currentUserId != m.organizerId) return false;
      await _sb
          .from('matches')
          .update({
            'status': 'cancelled',
            'cancellation_reason': 'cancelled_by_organizer',
          })
          .eq('id', matchId);
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

  Future<bool> saveMultiTeamResults(
    String matchId,
    List<Map<String, int>> stats,
  ) async {
    try {
      await _sb
          .from('matches')
          .update({'cancellation_reason': 'multi_team_stats:${stats.length}'})
          .eq('id', matchId);
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
    // Persist source_team_id so the legacy mapper can resolve teamAId/teamBId
    // and stat aggregation can correlate match_teams to the originating team.
    final matchTeamId = await _ensureMatchTeam(
      matchId,
      slot,
      team.name,
      sourceTeamId: team.id,
    );
    await _sb
        .from('match_team_rosters')
        .delete()
        .eq('match_team_id', matchTeamId);
    final ratingsById = await _loadProfileRatings(playerIds);
    for (final playerId in playerIds) {
      await _sb.from('match_team_rosters').insert({
        'match_team_id': matchTeamId,
        'player_id': playerId,
        'status': 'pending',
      });
    }
    await _sb
        .from('match_teams')
        .update({
          'team_total_rating': _sumTeamTotalRating(playerIds, ratingsById),
        })
        .eq('id', matchTeamId);
  }

  Future<void> respondToRosterInvite({
    required String matchId,
    required String teamKey,
    required bool accept,
  }) async {
    final uid = AppAuth.currentUserId;
    if (uid == null) throw Exception(tr('match_error_auth_required'));
    final slot = teamKey == 'teamA' ? 1 : 2;
    final teamId = await _ensureMatchTeam(
      matchId,
      slot,
      slot == 1 ? tr('match_default_team_a') : tr('match_default_team_b'),
    );
    await _sb
        .from('match_team_rosters')
        .update({
          'status': accept ? 'confirmed' : 'declined',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('match_team_id', teamId)
        .eq('player_id', uid);
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

  Future<String> _createMatchTeam(
    String matchId,
    int slot,
    String name, {
    double totalRating = 0,
    String? sourceTeamId,
  }) async {
    final inserted = await _sb
        .from('match_teams')
        .insert({
          'match_id': matchId,
          'team_slot': slot,
          'display_name': name,
          'team_total_rating': totalRating,
          if (sourceTeamId != null && sourceTeamId.isNotEmpty)
            'source_team_id': sourceTeamId,
        })
        .select('id')
        .single();
    return inserted['id'].toString();
  }

  Future<String> _ensureMatchTeam(
    String matchId,
    int slot,
    String name, {
    String? sourceTeamId,
  }) async {
    // Prefer existing row keyed by source_team_id so a re-roster from the
    // captain UI never duplicates a team into the wrong slot.
    if (sourceTeamId != null && sourceTeamId.isNotEmpty) {
      final bySource = await _sb
          .from('match_teams')
          .select('id,team_slot,source_team_id,display_name')
          .eq('match_id', matchId)
          .eq('source_team_id', sourceTeamId)
          .maybeSingle();
      if (bySource != null) {
        final id = bySource['id'].toString();
        await _backfillMatchTeamMetadata(
          id,
          slot: slot,
          sourceTeamId: sourceTeamId,
          name: name,
          existing: bySource,
        );
        return id;
      }
    }

    final bySlot = await _sb
        .from('match_teams')
        .select('id,team_slot,source_team_id,display_name')
        .eq('match_id', matchId)
        .eq('team_slot', slot)
        .maybeSingle();
    if (bySlot != null) {
      final id = bySlot['id'].toString();
      await _backfillMatchTeamMetadata(
        id,
        slot: slot,
        sourceTeamId: sourceTeamId,
        name: name,
        existing: bySlot,
      );
      return id;
    }

    return _createMatchTeam(
      matchId,
      slot,
      name,
      sourceTeamId: sourceTeamId,
    );
  }

  Future<void> _backfillMatchTeamMetadata(
    String matchTeamId, {
    required int slot,
    required String? sourceTeamId,
    required String name,
    required Map<String, dynamic> existing,
  }) async {
    final updates = <String, dynamic>{};
    if (sourceTeamId != null && sourceTeamId.isNotEmpty) {
      final currentSource =
          (existing['source_team_id'] ?? '').toString();
      if (currentSource.isEmpty) {
        updates['source_team_id'] = sourceTeamId;
      }
    }
    final currentName = (existing['display_name'] ?? '').toString().trim();
    if (currentName.isEmpty && name.isNotEmpty) {
      updates['display_name'] = name;
    }
    final currentSlot = existing['team_slot'];
    if (currentSlot is num && currentSlot.toInt() != slot) {
      updates['team_slot'] = slot;
    }
    if (updates.isEmpty) return;
    await _sb.from('match_teams').update(updates).eq('id', matchTeamId);
  }
}
