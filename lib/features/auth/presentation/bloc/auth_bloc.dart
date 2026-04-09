import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth_failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository, this._userProfiles) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthSessionCleared>(_onSessionCleared);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
  }

  final AuthRepository _repository;
  final UserProfileRepository _userProfiles;
  StreamSubscription<AppUser?>? _authSubscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await _authSubscription?.cancel();
    final initial = _repository.currentUser;
    if (initial != null) {
      emit(AuthAuthenticated(initial));
    } else {
      emit(const AuthUnauthenticated());
    }
    _authSubscription = _repository.authStateChanges.listen((user) {
      if (isClosed) return;
      if (user != null) {
        add(AuthUserChanged(user));
      } else {
        add(const AuthSessionCleared());
      }
    });
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    emit(AuthAuthenticated(event.user));
  }

  void _onSessionCleared(AuthSessionCleared event, Emitter<AuthState> emit) {
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repository.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      final u = _repository.currentUser;
      if (u != null) {
        emit(AuthAuthenticated(u));
      } else {
        emit(const AuthUnauthenticated());
      }
    } on AuthFailure catch (e) {
      emit(AuthCredentialsRejected(code: e.code, message: e.message));
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await _repository.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.signUpWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      await _userProfiles.createAfterSignUp(
        userId: user.id,
        profile: event.profile,
      );
      await _repository.signOut();
      emit(AuthRegistrationCompleted(email: event.email));
      emit(const AuthUnauthenticated());
    } on AuthFailure catch (e) {
      emit(AuthCredentialsRejected(code: e.code, message: e.message));
      emit(const AuthUnauthenticated());
    } catch (e) {
      if (_repository.currentUser != null) {
        await _repository.signOut();
      }
      emit(AuthCredentialsRejected(
        code: 'registration-failed',
        message: e.toString(),
      ));
      emit(const AuthUnauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
