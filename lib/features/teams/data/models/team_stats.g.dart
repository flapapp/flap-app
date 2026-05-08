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
      cleanSheets: (json['cleanSheets'] as num?)?.toInt() ?? 0,
      currentWinStreak: (json['currentWinStreak'] as num?)?.toInt() ?? 0,
      currentUnbeatenStreak:
          (json['currentUnbeatenStreak'] as num?)?.toInt() ?? 0,
      longestWinStreak: (json['longestWinStreak'] as num?)?.toInt() ?? 0,
      recentForm: (json['recentForm'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      lastFinishedMatchAt: json['lastFinishedMatchAt'] == null
          ? null
          : DateTime.parse(json['lastFinishedMatchAt'] as String),
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
      'cleanSheets': instance.cleanSheets,
      'currentWinStreak': instance.currentWinStreak,
      'currentUnbeatenStreak': instance.currentUnbeatenStreak,
      'longestWinStreak': instance.longestWinStreak,
      'recentForm': instance.recentForm,
      'lastFinishedMatchAt': instance.lastFinishedMatchAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
