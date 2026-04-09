import 'package:equatable/equatable.dart';

/// Fields collected on the registration form (before avatar URL is known).
class NewUserProfile extends Equatable {
  const NewUserProfile({
    required this.name,
    required this.surname,
    required this.email,
    required this.phone,
    required this.city,
    required this.age,
    required this.position,
    required this.experience,
  });

  final String name;
  final String surname;
  final String email;
  final String phone;
  final String city;
  final int age;
  final String position;
  final String experience;

  String get displayFullName => '$name $surname'.trim();

  @override
  List<Object?> get props =>
      [name, surname, email, phone, city, age, position, experience];
}
