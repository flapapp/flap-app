// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_rating_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerRating _$PlayerRatingFromJson(Map<String, dynamic> json) => PlayerRating(
      playerId: json['playerId'] as String,
      ratedBy: json['ratedBy'] as String,
      rating: (json['rating'] as num).toDouble(),
      ratedAt: DateTime.parse(json['ratedAt'] as String),
      criteria: (json['criteria'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ) ??
          const {},
    );

Map<String, dynamic> _$PlayerRatingToJson(PlayerRating instance) =>
    <String, dynamic>{
      'playerId': instance.playerId,
      'ratedBy': instance.ratedBy,
      'rating': instance.rating,
      'ratedAt': instance.ratedAt.toIso8601String(),
      'criteria': instance.criteria,
    };
