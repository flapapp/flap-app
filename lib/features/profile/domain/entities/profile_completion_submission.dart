import 'package:equatable/equatable.dart';

class ProfileCompletionSubmission extends Equatable {
  const ProfileCompletionSubmission({
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
  final DateTime dateOfBirth;
  final String position;
  final String experience;

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
