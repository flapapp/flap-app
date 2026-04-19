import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory PlayerRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlayerRating(
      playerId: data['playerId'] ?? '',
      ratedBy: data['ratedBy'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratedAt: (data['ratedAt'] as Timestamp).toDate(),
      criteria: Map<String, double>.from(data['criteria'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'playerId': playerId,
      'ratedBy': ratedBy,
      'rating': rating,
      'ratedAt': Timestamp.fromDate(ratedAt),
      'criteria': criteria,
    };
  }

  factory PlayerRating.fromJson(Map<String, dynamic> json) =>
      _$PlayerRatingFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerRatingToJson(this);
}
