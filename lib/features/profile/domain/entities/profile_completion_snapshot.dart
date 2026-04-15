import 'package:equatable/equatable.dart';

class ProfileCompletionSnapshot extends Equatable {
  const ProfileCompletionSnapshot({
    this.name,
    this.surname,
    this.phone,
    this.country,
    this.city,
    this.dateOfBirth,
    this.position,
    this.experience,
    this.avatarUrl,
  });

  final String? name;
  final String? surname;
  final String? phone;
  final String? country;
  final String? city;
  final DateTime? dateOfBirth;
  final String? position;
  final String? experience;
  final String? avatarUrl;

  @override
  List<Object?> get props => [
        name,
        surname,
        phone,
        country,
        city,
        dateOfBirth,
        position,
        experience,
        avatarUrl,
      ];
}
