import 'package:equatable/equatable.dart';

import 'player_position.dart';

/// Squad member (maps to `public.players`); [userId] is the owning account.
class Player extends Equatable {
  const Player({
    this.id,
    this.teamId,
    this.userId,
    required this.name,
    required this.position,
    required this.jerseyNumber,
    this.age,
    this.nationality,
  });

  final String? id;
  final String? teamId;
  /// Set when persisting; optional while editing the wizard draft.
  final String? userId;
  final String name;
  final PlayerPosition position;
  final int jerseyNumber;
  final int? age;
  final String? nationality;

  Player copyWith({
    String? id,
    String? teamId,
    String? userId,
    String? name,
    PlayerPosition? position,
    int? jerseyNumber,
    int? age,
    String? nationality,
  }) {
    return Player(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
    );
  }

  @override
  List<Object?> get props => [
        id,
        teamId,
        userId,
        name,
        position,
        jerseyNumber,
        age,
        nationality,
      ];
}
