import 'package:equatable/equatable.dart';

/// Full profile fields collected on the post-login completion screen.
class CompleteProfileSubmission extends Equatable {
  const CompleteProfileSubmission({
    required this.name,
    required this.surname,
    required this.phone,
    required this.city,
    required this.age,
    required this.position,
    required this.experience,
  });

  final String name;
  final String surname;
  final String phone;
  final String city;
  final int age;
  final String position;
  final String experience;

  String get displayFullName => '$name $surname'.trim();

  @override
  List<Object?> get props => [
    name,
    surname,
    phone,
    city,
    age,
    position,
    experience,
  ];
}
