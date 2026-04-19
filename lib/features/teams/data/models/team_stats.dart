import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/team_stats_entity.dart';

export '../../domain/entities/team_stats_entity.dart';

part 'team_stats.g.dart';

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
    super.updatedAt,
  });

  factory TeamStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TeamStats.fromFirestoreMap(doc.id, doc.data(), fallbackName: '');
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
    return TeamStats(
      teamId: teamId,
      teamName: (d['teamName'] ?? fallbackName).toString(),
      wins: ((d['wins'] ?? 0) as num).toInt(),
      draws: ((d['draws'] ?? 0) as num).toInt(),
      losses: ((d['losses'] ?? 0) as num).toInt(),
      goalsFor: ((d['goalsFor'] ?? 0) as num).toInt(),
      goalsAgainst: ((d['goalsAgainst'] ?? 0) as num).toInt(),
      playerGoals: Map<String, int>.from(
        (d['playerGoals'] ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      ),
      recentMatches: ((d['recentMatches'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
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


