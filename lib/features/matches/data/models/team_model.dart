import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/match_team_entity.dart';

export '../../domain/entities/match_team_entity.dart';

part 'team_model.g.dart';

@JsonSerializable(explicitToJson: true)
class Team extends MatchTeamEntity {
  const Team({
    required super.name,
    required super.playerIds,
    super.averageRating = 0.0,
    super.playerRatings = const {},
  });

  factory Team.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Team(
      name: data['name'] ?? '',
      playerIds: List<String>.from(data['playerIds'] ?? []),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      playerRatings: Map<String, double>.from(data['playerRatings'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'playerIds': playerIds,
      'averageRating': averageRating,
      'playerRatings': playerRatings,
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) => _$TeamFromJson(json);

  Map<String, dynamic> toJson() => _$TeamToJson(this);

  Team copyWith({
    String? name,
    List<String>? playerIds,
    double? averageRating,
    Map<String, double>? playerRatings,
  }) {
    return Team(
      name: name ?? this.name,
      playerIds: playerIds ?? this.playerIds,
      averageRating: averageRating ?? this.averageRating,
      playerRatings: playerRatings ?? this.playerRatings,
    );
  }
}
