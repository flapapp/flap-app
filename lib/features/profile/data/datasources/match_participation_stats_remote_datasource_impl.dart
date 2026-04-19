import 'package:supabase_flutter/supabase_flutter.dart';

import 'match_participation_stats_remote_datasource.dart';

class MatchParticipationStatsRemoteDataSourceImpl
    implements MatchParticipationStatsRemoteDataSource {
  MatchParticipationStatsRemoteDataSourceImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> loadFinishedMatchStats(String userId) async {
    try {
      final partRows = await _client
          .from('match_participants')
          .select('match_id')
          .eq('user_id', userId)
          .eq('status', 'accepted');
      final matchIds = (partRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['match_id'] as String)
          .toSet()
          .toList();
      if (matchIds.isEmpty) {
        return _empty;
      }

      final matchRows = await _client
          .from('matches')
          .select('id,status,finished_at,updated_at')
          .eq('status', 'finished')
          .inFilter('id', matchIds)
          .order('finished_at', ascending: false)
          .limit(20);

      var wins = 0;
      var draws = 0;
      var losses = 0;
      final recent = <String>[];

      for (final raw in (matchRows as List<dynamic>)) {
        final m = raw as Map<String, dynamic>;
        final mid = m['id'] as String;
        final outcome = await _outcomeForUser(mid, userId);
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
      return {
        'winRate': rate,
        'wins': wins,
        'draws': draws,
        'losses': losses,
        'matches': total,
        'recentResults': recent,
      };
    } catch (_) {
      return _empty;
    }
  }

  static const _empty = <String, dynamic>{
    'winRate': 0.0,
    'wins': 0,
    'draws': 0,
    'losses': 0,
    'matches': 0,
    'recentResults': ['-', '-', '-', '-', '-'],
  };

  Future<String?> _outcomeForUser(String matchId, String userId) async {
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

  Future<bool> _rosterContains(String matchTeamId, String userId) async {
    final row = await _client
        .from('match_team_rosters')
        .select('player_id')
        .eq('match_team_id', matchTeamId)
        .eq('player_id', userId)
        .maybeSingle();
    return row != null;
  }
}
