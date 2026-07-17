import 'package:supabase_flutter/supabase_flutter.dart';

import 'match_participation_stats_remote_datasource.dart';

/// Whether a roster row should count for finished-match statistics.
/// Declined spots never played; empty/null legacy rows still count.
bool rosterStatusCountsForMatchStats(String? status) {
  final s = (status ?? '').trim().toLowerCase();
  if (s.isEmpty) return true;
  return s != 'declined';
}

class MatchParticipationStatsRemoteDataSourceImpl
    implements MatchParticipationStatsRemoteDataSource {
  MatchParticipationStatsRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> loadFinishedMatchStats(String userId) async {
    try {
      final goalsFuture = _sumParticipantGoals(userId);

      // The two id sources are independent — fetch them concurrently.
      final idResults = await Future.wait([
        _finishedMatchIdsFromParticipants(userId),
        _finishedMatchIdsFromTeamRosters(userId),
      ]);
      final matchIds =
          {...idResults[0], ...idResults[1]}.toList(growable: false);
      if (matchIds.isEmpty) {
        final g = await goalsFuture;
        return {..._empty, 'totalGoals': g};
      }

      final matchRows = await _client
          .from('matches')
          .select('id,status,finished_at,cancellation_reason')
          .eq('status', 'finished')
          .inFilter('id', matchIds)
          .order('finished_at', ascending: false);

      var wins = 0;
      var draws = 0;
      var losses = 0;
      final recent = <String>[];

      // Resolve each match outcome concurrently. Future.wait preserves list
      // order, so `recent` still reflects finished_at-descending order below.
      final rows = (matchRows as List<dynamic>).cast<Map<String, dynamic>>();
      final outcomes = await Future.wait(
        rows.map(
          (m) => _outcomeForUser(m['id'] as String, userId, matchRow: m),
        ),
      );

      for (final outcome in outcomes) {
        if (outcome == null) {
          continue;
        }
        if (outcome == 'D') {
          draws++;
        } else if (outcome == 'W') {
          wins++;
        } else {
          losses++;
        }
        if (recent.length < 5) {
          recent.add(outcome);
        }
      }

      final total = wins + draws + losses;
      final rate = total > 0 ? (wins / total) * 100 : 0.0;
      while (recent.length < 5) {
        recent.add('-');
      }
      final totalGoals = await goalsFuture;
      return {
        'winRate': rate,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'matches': total,
        'recentResults': recent,
        'totalGoals': totalGoals,
      };
    } catch (_) {
      return _empty;
    }
  }

  Future<List<String>> _finishedMatchIdsFromParticipants(String userId) async {
    try {
      final partRows = await _client
          .from('match_participants')
          .select('match_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');
      return (partRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['match_id'].toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Team matches often omit `match_participants`; roster defines participation.
  Future<List<String>> _finishedMatchIdsFromTeamRosters(String userId) async {
    try {
      final rows = await _client
          .from('match_team_rosters')
          .select('status, match_teams(match_id)')
          .eq('player_id', userId);
      final ids = <String>{};
      for (final raw in rows as List<dynamic>) {
        final r = raw as Map<String, dynamic>;
        if (!rosterStatusCountsForMatchStats(r['status']?.toString())) {
          continue;
        }
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
      return ids.toList();
    } catch (_) {
      return [];
    }
  }

  static const _empty = <String, dynamic>{
    'winRate': 0.0,
    'wins': 0,
    'draws': 0,
    'losses': 0,
    'matches': 0,
    'recentResults': ['-', '-', '-', '-', '-'],
    'totalGoals': 0,
  };

  Future<int> _sumParticipantGoals(String userId) async {
    try {
      final rows = await _client
          .from('match_participant_goals')
          .select('goals')
          .eq('player_id', userId);
      var sum = 0;
      for (final r in rows as List<dynamic>) {
        sum += ((r as Map<String, dynamic>)['goals'] as num?)?.toInt() ?? 0;
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  /// Prefer a finished [match_fixture]; fall back to two-team scores in [matches.cancellation_reason]
  /// (most casual matches never create fixtures — see [MatchService.ensureFixtures]).
  Future<String?> _outcomeForUser(
    String matchId,
    String userId, {
    required Map<String, dynamic> matchRow,
  }) async {
    final fromFx = await _outcomeFromFixture(matchId, userId);
    if (fromFx != null) {
      return fromFx;
    }
    return _outcomeFromCancellationRow(matchRow, matchId, userId);
  }

  Future<String?> _outcomeFromFixture(String matchId, String userId) async {
    final fx = await _client
        .from('match_fixtures')
        .select(
          'home_score,away_score,home_match_team_id,away_match_team_id,status',
        )
        .eq('match_id', matchId)
        .eq('status', 'finished')
        .limit(1)
        .maybeSingle();
    if (fx == null) {
      return null;
    }
    final hs = (fx['home_score'] as num?)?.toInt();
    final as = (fx['away_score'] as num?)?.toInt();
    if (hs == null || as == null) {
      return null;
    }
    final homeId = fx['home_match_team_id'] as String?;
    final awayId = fx['away_match_team_id'] as String?;
    if (homeId == null || awayId == null) {
      return null;
    }
    final onHome = await _rosterContains(homeId, userId);
    final onAway = await _rosterContains(awayId, userId);
    if (!onHome && !onAway) {
      return null;
    }
    if (hs == as) {
      return 'D';
    }
    final homeWins = hs > as;
    if (onHome) {
      return homeWins ? 'W' : 'L';
    }
    return homeWins ? 'L' : 'W';
  }

  /// Parses scores saved by [MatchService.finishMatch]: `teamAWins|teamBWins|draw:scoreA:scoreB`.
  Future<String?> _outcomeFromCancellationRow(
    Map<String, dynamic> matchRow,
    String matchId,
    String userId,
  ) async {
    final raw = matchRow['cancellation_reason']?.toString();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parts = raw.split(':');
    if (parts.length != 3) {
      return null;
    }
    final rName = parts[0];
    if (rName != 'teamAWins' && rName != 'teamBWins' && rName != 'draw') {
      return null;
    }
    final a = int.tryParse(parts[1]);
    final b = int.tryParse(parts[2]);
    if (a == null || b == null) {
      return null;
    }

    final teamsResp = await _client
        .from('match_teams')
        .select('id,team_slot')
        .eq('match_id', matchId)
        .order('team_slot', ascending: true);
    final tlist = (teamsResp as List<dynamic>).cast<Map<String, dynamic>>();
    if (tlist.length < 2) {
      return null;
    }

    // Align with [MatchService.finishMatch] / [MatchLegacyRemoteMapper]: team A =
    // match_teams.team_slot == 1, team B == 2. Do not rely on list indices alone
    // (ordering defaults have regressed W/L before).
    String? idForSlot(int slot) {
      for (final t in tlist) {
        if ((t['team_slot'] as num?)?.toInt() == slot) {
          final id = t['id']?.toString();
          if (id != null && id.isNotEmpty) return id;
        }
      }
      return null;
    }

    var idA = idForSlot(1);
    var idB = idForSlot(2);
    idA ??= tlist[0]['id']?.toString();
    idB ??= tlist[1]['id']?.toString();
    if (idA == null || idB == null || idA.isEmpty || idB.isEmpty) {
      return null;
    }

    final onA = await _rosterContains(idA, userId);
    final onB = await _rosterContains(idB, userId);
    if (!onA && !onB) {
      return null;
    }

    if (rName == 'draw' || a == b) {
      return 'D';
    }

    // Same semantics as stored by finish flow: teamAWins => slot 1 won.
    if (rName == 'teamAWins') {
      return onA ? 'W' : 'L';
    }
    if (rName == 'teamBWins') {
      return onB ? 'W' : 'L';
    }
    return null;
  }

  Future<bool> _rosterContains(String matchTeamId, String userId) async {
    final row = await _client
        .from('match_team_rosters')
        .select('player_id,status')
        .eq('match_team_id', matchTeamId)
        .eq('player_id', userId)
        .maybeSingle();
    if (row == null) return false;
    return rosterStatusCountsForMatchStats(row['status']?.toString());
  }
}
