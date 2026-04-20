import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/player_rating_entity.dart';

export '../../domain/entities/player_rating_entity.dart';

part 'player_rating_model.g.dart';

@JsonSerializable(explicitToJson: true)
class PlayerRating extends PlayerRatingEntity {
  const PlayerRating({
    required super.playerId,
    required super.ratedBy,
    required super.rating,
    required super.ratedAt,
    super.criteria = const {},
  });

  static DateTime _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      final dynamic v = value;
      final date = v?.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    return DateTime.now();
  }

  factory PlayerRating.fromFirestore(dynamic doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return PlayerRating(
      playerId: data['playerId'] ?? '',
      ratedBy: data['ratedBy'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratedAt: _readDate(data['ratedAt']),
      criteria: Map<String, double>.from(data['criteria'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'ratedBy': ratedBy,
      'rating': rating,
      'ratedAt': ratedAt,
      'criteria': criteria,
    };
  }

  factory PlayerRating.fromJson(Map<String, dynamic> json) =>
      _$PlayerRatingFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerRatingToJson(this);
}
