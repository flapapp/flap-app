import 'package:equatable/equatable.dart';

class BadgeEntity extends Equatable {
  const BadgeEntity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.price,
    required this.category,
    this.isAvailable = true,
    this.releaseDate,
  });

  final String id;
  final String name;
  final String emoji;
  final String description;
  final int price;
  final String category;
  final bool isAvailable;
  final DateTime? releaseDate;

  @override
  List<Object?> get props =>
      [id, name, emoji, description, price, category, isAvailable, releaseDate];
}
