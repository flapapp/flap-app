import 'package:equatable/equatable.dart';

/// Full profile fields collected on the post-login completion screen.
class CompleteProfileSubmission extends Equatable {
  const CompleteProfileSubmission({
    required this.name,
    required this.surname,
    required this.phone,
    required this.country,
    required this.city,
    required this.dateOfBirth,
    required this.position,
    required this.experience,
  });

  final String name;
  final String surname;
  final String phone;
  final String country;
  final String city;
  /// Calendar date only (maps to `user_profiles.date_of_birth`).
  final DateTime dateOfBirth;
  final String position;
  final String experience;

  String get displayFullName => '$name $surname'.trim();

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
  ];
}
