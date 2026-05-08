import 'package:json_annotation/json_annotation.dart';

import '../../../../core/supabase/supabase_date.dart';
import '../../domain/entities/team_stats_entity.dart';

export '../../domain/entities/team_stats_entity.dart';

part 'team_stats.g.dart';

/// Translates a row from `public.team_stats` (snake_case) joined with the team
/// name into the camelCase shape `TeamStats.fromFirestoreMap` expects. Pure
/// function — used by every datasource that reads the new `team_stats`
/// table and locked in by unit tests against the SQL contract from
/// `20260508140000_team_stats_aggregation_and_history.sql`.
Map<String, dynamic> mapTeamStatsRowToLegacyShape(
  Map<String, dynamic> row, {
  String fallbackName = '',
}) {
  int asInt(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, int> asPlayerGoals(dynamic v) {
    if (v is Map) {
      final out = <String, int>{};
      v.forEach((key, value) {
        final id = key?.toString() ?? '';
        if (id.isEmpty) return;
        if (value is num) out[id] = value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) out[id] = parsed;
        }
      });
      return out;
    }
    return const <String, int>{};
  }

  List<String> asForm(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const <String>[];
  }

  List<Map<String, dynamic>> asRecent(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) {
        return e.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  return <String, dynamic>{
    'teamName': (row['team_name'] ?? row['teamName'] ?? fallbackName).toString(),
    'wins': asInt(row['wins']),
    'draws': asInt(row['draws']),
    'losses': asInt(row['losses']),
    'goalsFor': asInt(row['goals_for'] ?? row['goalsFor']),
    'goalsAgainst': asInt(row['goals_against'] ?? row['goalsAgainst']),
    'playerGoals': asPlayerGoals(row['player_goals'] ?? row['playerGoals']),
    'recentMatches': asRecent(row['recent_matches'] ?? row['recentMatches']),
    'cleanSheets': asInt(row['clean_sheets'] ?? row['cleanSheets']),
    'currentWinStreak':
        asInt(row['current_win_streak'] ?? row['currentWinStreak']),
    'currentUnbeatenStreak': asInt(
        row['current_unbeaten_streak'] ?? row['currentUnbeatenStreak']),
    'longestWinStreak':
        asInt(row['longest_win_streak'] ?? row['longestWinStreak']),
    'recentForm': asForm(row['recent_form'] ?? row['recentForm']),
    'lastFinishedMatchAt':
        row['last_finished_match_at'] ?? row['lastFinishedMatchAt'],
    'updatedAt': row['updated_at'] ?? row['updatedAt'],
  };
}

@JsonSerializable(explicitToJson: true)
class TeamStats extends TeamStatsEntity {
  const TeamStats({
    required super.teamId,
    required super.teamName,
    super.wins = 0,
    super.draws = 0,
    super.losses = 0,
    super.goalsFor = 0,
    super.goalsAgainst = 0,
    super.playerGoals = const {},
    super.recentMatches = const [],
    super.cleanSheets = 0,
    super.currentWinStreak = 0,
    super.currentUnbeatenStreak = 0,
    super.longestWinStreak = 0,
    super.recentForm = const [],
    super.lastFinishedMatchAt,
    super.updatedAt,
  });

  factory TeamStats.fromDoc(dynamic doc) {
    final id = doc.id as String;
    final data = doc.data();
    final map = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    return TeamStats.fromFirestoreMap(id, map, fallbackName: '');
  }

  /// Snapshot data from `teamStats/{teamId}` (same shape as [fromDoc]).
  factory TeamStats.fromFirestoreMap(
    String teamId,
    Map<String, dynamic>? data, {
    String fallbackName = '',
  }) {
    final d = data ?? const <String, dynamic>{};
    if (d.isEmpty) {
      return TeamStats.empty(teamId, name: fallbackName);
    }
    int asInt(dynamic v, [int fallback = 0]) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return TeamStats(
      teamId: teamId,
      teamName: (d['teamName'] ?? fallbackName).toString(),
      wins: asInt(d['wins']),
      draws: asInt(d['draws']),
      losses: asInt(d['losses']),
      goalsFor: asInt(d['goalsFor']),
      goalsAgainst: asInt(d['goalsAgainst']),
      playerGoals: Map<String, int>.from(
        (d['playerGoals'] ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), asInt(value)),
        ),
      ),
      recentMatches: ((d['recentMatches'] as List?) ?? const [])
          .map((e) {
            if (e is Map) {
              return e.map(
                (key, value) => MapEntry(key.toString(), value),
              );
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList(),
      cleanSheets: asInt(d['cleanSheets']),
      currentWinStreak: asInt(d['currentWinStreak']),
      currentUnbeatenStreak: asInt(d['currentUnbeatenStreak']),
      longestWinStreak: asInt(d['longestWinStreak']),
      recentForm: ((d['recentForm'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      lastFinishedMatchAt: asDateTimeOrNull(d['lastFinishedMatchAt']),
      updatedAt: asDateTimeOrNull(d['updatedAt'] ?? d['updated_at']),
    );
  }

  static TeamStats empty(String teamId, {String name = ''}) {
    return TeamStats(teamId: teamId, teamName: name);
  }

  factory TeamStats.fromJson(Map<String, dynamic> json) =>
      _$TeamStatsFromJson(json);

  Map<String, dynamic> toJson() => _$TeamStatsToJson(this);

  int get matches => wins + draws + losses;
  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
}


