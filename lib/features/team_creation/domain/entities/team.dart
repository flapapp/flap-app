import 'package:equatable/equatable.dart';

/// Club / team row (maps to `public.teams` extended columns).
class Team extends Equatable {
  const Team({
    this.id,
    required this.name,
    this.shortName,
    this.foundedYear,
    this.country,
    this.city,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String? shortName;
  final int? foundedYear;
  final String? country;
  final String? city;
  final String? logoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final DateTime? createdAt;

  Team copyWith({
    String? id,
    String? name,
    String? shortName,
    int? foundedYear,
    String? country,
    String? city,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
    DateTime? createdAt,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      foundedYear: foundedYear ?? this.foundedYear,
      country: country ?? this.country,
      city: city ?? this.city,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        shortName,
        foundedYear,
        country,
        city,
        logoUrl,
        primaryColor,
        secondaryColor,
        createdAt,
      ];
}
