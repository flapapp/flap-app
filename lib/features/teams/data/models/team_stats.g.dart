// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamStats _$TeamStatsFromJson(Map<String, dynamic> json) => TeamStats(
      teamId: json['teamId'] as String,
      teamName: json['teamName'] as String,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      goalsFor: (json['goalsFor'] as num?)?.toInt() ?? 0,
      goalsAgainst: (json['goalsAgainst'] as num?)?.toInt() ?? 0,
      playerGoals: (json['playerGoals'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      recentMatches: (json['recentMatches'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$TeamStatsToJson(TeamStats instance) => <String, dynamic>{
      'teamId': instance.teamId,
      'teamName': instance.teamName,
      'wins': instance.wins,
      'draws': instance.draws,
      'losses': instance.losses,
      'goalsFor': instance.goalsFor,
      'goalsAgainst': instance.goalsAgainst,
      'playerGoals': instance.playerGoals,
      'recentMatches': instance.recentMatches,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
