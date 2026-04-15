import 'package:equatable/equatable.dart';

/// Minimal fields collected on the sign-up form.
class RegistrationProfile extends Equatable {
  const RegistrationProfile({
    required this.email,
    required this.username,
  });

  final String email;
  final String username;

  @override
  List<Object?> get props => [email, username];
}
