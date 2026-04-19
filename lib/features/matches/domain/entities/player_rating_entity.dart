import 'package:equatable/equatable.dart';

class PlayerRatingEntity extends Equatable {
  const PlayerRatingEntity({
    required this.playerId,
    required this.ratedBy,
    required this.rating,
    required this.ratedAt,
    this.criteria = const {},
  });

  final String playerId;
  final String ratedBy;
  final double rating;
  final DateTime ratedAt;
  final Map<String, double> criteria;

  @override
  List<Object?> get props =>
      [playerId, ratedBy, rating, ratedAt, criteria];
}
