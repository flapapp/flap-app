import 'package:equatable/equatable.dart';

class MatchTeamEntity extends Equatable {
  const MatchTeamEntity({
    required this.name,
    required this.playerIds,
    this.averageRating = 0.0,
    this.playerRatings = const {},
  });

  final String name;
  final List<String> playerIds;
  final double averageRating;
  final Map<String, double> playerRatings;

  @override
  List<Object?> get props => [name, playerIds, averageRating, playerRatings];
}
