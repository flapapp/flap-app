import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_profile.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthUserChanged extends AuthEvent {
  const AuthUserChanged(this.user);

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

class AuthSessionCleared extends AuthEvent {
  const AuthSessionCleared();
}

class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.profile,
  });

  final String email;
  final String password;
  final RegistrationProfile profile;

  @override
  List<Object?> get props => [email, password, profile];
}
