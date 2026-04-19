// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Team _$TeamFromJson(Map<String, dynamic> json) => Team(
      name: json['name'] as String,
      playerIds:
          (json['playerIds'] as List<dynamic>).map((e) => e as String).toList(),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      playerRatings: (json['playerRatings'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ) ??
          const {},
    );

Map<String, dynamic> _$TeamToJson(Team instance) => <String, dynamic>{
      'name': instance.name,
      'playerIds': instance.playerIds,
      'averageRating': instance.averageRating,
      'playerRatings': instance.playerRatings,
    };
