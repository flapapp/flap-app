// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_team.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppTeam _$AppTeamFromJson(Map<String, dynamic> json) => AppTeam(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      captainId: json['captainId'] as String,
      viceCaptainIds: (json['viceCaptainIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      memberIds:
          (json['memberIds'] as List<dynamic>).map((e) => e as String).toList(),
      isPublic: json['isPublic'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      logoUrl: json['logoUrl'] as String?,
      city: json['city'] as String?,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
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
    );

Map<String, dynamic> _$AppTeamToJson(AppTeam instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'captainId': instance.captainId,
      'viceCaptainIds': instance.viceCaptainIds,
      'memberIds': instance.memberIds,
      'isPublic': instance.isPublic,
      'logoUrl': instance.logoUrl,
      'city': instance.city,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'wins': instance.wins,
      'losses': instance.losses,
      'draws': instance.draws,
      'goalsFor': instance.goalsFor,
      'goalsAgainst': instance.goalsAgainst,
      'playerGoals': instance.playerGoals,
      'recentMatches': instance.recentMatches,
    };
