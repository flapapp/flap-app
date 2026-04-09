import 'package:equatable/equatable.dart';

/// Minimal fields collected on the sign-up form (credentials + display names only).
class RegistrationProfile extends Equatable {
  const RegistrationProfile({
    required this.name,
    required this.surname,
    required this.email,
  });

  final String name;
  final String surname;
  final String email;

  String get displayFullName => '$name $surname'.trim();

  @override
  List<Object?> get props => [name, surname, email];
}
