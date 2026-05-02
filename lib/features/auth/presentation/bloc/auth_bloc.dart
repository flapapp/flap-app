import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../core/usecases/no_params.dart';
import '../../domain/contracts/post_login_actions.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/register_request.dart';
import '../../domain/entities/startup_destination.dart';
import '../../domain/usecases/check_intro_completed_usecase.dart';
import '../../domain/usecases/mark_intro_completed_usecase.dart';
import '../../domain/usecases/register_new_user_usecase.dart';
import '../../domain/usecases/resolve_startup_navigation_usecase.dart';
import '../../domain/usecases/sign_in_with_email_usecase.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../../router/post_auth_navigation.dart';

part 'auth_bloc.freezed.dart';

/// Single BLoC for the auth module (bootstrap, sign-in, registration, intro gate).
@freezed
class AuthEvent with _$AuthEvent {
  const factory AuthEvent.bootstrapRequested() = AuthBootstrapRequested;

  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;

  const factory AuthEvent.registrationRequested(RegisterRequest request) =
      AuthRegistrationRequested;

  const factory AuthEvent.loginFormOpened() = AuthLoginFormOpened;

  const factory AuthEvent.registrationFormOpened() = AuthRegistrationFormOpened;

  /// One-time intro: check local flag vs redirect to welcome.
  const factory AuthEvent.introGateCheckRequested() = AuthIntroGateCheckRequested;

  /// One-time intro: persist completion then UI navigates on success.
  const factory AuthEvent.introMarkCompletedRequested() =
      AuthIntroMarkCompletedRequested;
}

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    @Default(ProgressStatus.pure) ProgressStatus bootstrapProgress,
    @Default(ProgressStatus.pure) ProgressStatus loginProgress,
    @Default(ProgressStatus.pure) ProgressStatus registrationProgress,
    @Default(ProgressStatus.pure) ProgressStatus introGateProgress,
    @Default(ProgressStatus.pure) ProgressStatus introMarkProgress,
    StartupDestination? bootstrapDestination,
    Failure? bootstrapFailure,
    Failure? loginFailure,
    Failure? registrationFailure,
    Failure? introGateFailure,
    Failure? introMarkFailure,
    /// After intro gate succeeds: `true` = skip intro UI, `false` = show it.
    bool? introShouldSkipToWelcome,
    AuthUser? lastAuthenticatedUser,
    /// Precomputed after email/password sign-in or registration (avoids a second profile fetch).
    PageRouteInfo<void>? postAuthNavigationRoute,
  }) = _AuthState;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required ResolveStartupNavigationUseCase resolveStartup,
    required SignInWithEmailUseCase signIn,
    required RegisterNewUserUseCase registerNewUser,
    required CheckIntroCompletedUseCase checkIntroCompleted,
    required MarkIntroCompletedUseCase markIntroCompleted,
    required PostLoginActions postLoginActions,
  })  : _resolveStartup = resolveStartup,
        _signIn = signIn,
        _registerNewUser = registerNewUser,
        _checkIntroCompleted = checkIntroCompleted,
        _markIntroCompleted = markIntroCompleted,
        _postLoginActions = postLoginActions,
        super(const AuthState()) {
    on<AuthBootstrapRequested>(_onBootstrapRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegistrationRequested>(_onRegistrationRequested);
    on<AuthLoginFormOpened>(_onLoginFormOpened);
    on<AuthRegistrationFormOpened>(_onRegistrationFormOpened);
    on<AuthIntroGateCheckRequested>(_onIntroGateCheckRequested);
    on<AuthIntroMarkCompletedRequested>(_onIntroMarkCompletedRequested);
  }

  final ResolveStartupNavigationUseCase _resolveStartup;
  final SignInWithEmailUseCase _signIn;
  final RegisterNewUserUseCase _registerNewUser;
  final CheckIntroCompletedUseCase _checkIntroCompleted;
  final MarkIntroCompletedUseCase _markIntroCompleted;
  final PostLoginActions _postLoginActions;

  Future<void> _onBootstrapRequested(
    AuthBootstrapRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      bootstrapProgress: ProgressStatus.loading,
      bootstrapFailure: null,
      bootstrapDestination: null,
    ));
    final result = await _resolveStartup(const NoParams());
    result.when(
      success: (destination) => emit(state.copyWith(
        bootstrapProgress: ProgressStatus.success,
        bootstrapDestination: destination,
      )),
      failure: (f) => emit(state.copyWith(
        bootstrapProgress: ProgressStatus.failure,
        bootstrapFailure: f,
      )),
    );
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.loginProgress == ProgressStatus.loading) {
      return;
    }
    emit(state.copyWith(
      loginProgress: ProgressStatus.loading,
      loginFailure: null,
    ));
    final result = await _signIn(
      SignInParams(email: event.email, password: event.password),
    );
    await result.when(
      success: (user) async {
        final profileFuture =
            sl<ProfileRepository>().fetchUserProfile(user.uid);
        unawaited(_postLoginActions.onEmailPasswordSignInSuccess(user));
        final profile = await profileFuture;
        emit(state.copyWith(
          loginProgress: ProgressStatus.success,
          lastAuthenticatedUser: user,
          postAuthNavigationRoute: postAuthRouteForProfile(profile),
        ));
      },
      failure: (f) async {
        emit(state.copyWith(
          loginProgress: ProgressStatus.failure,
          loginFailure: f,
        ));
      },
    );
  }

  Future<void> _onRegistrationRequested(
    AuthRegistrationRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state.registrationProgress == ProgressStatus.loading) {
      return;
    }
    emit(state.copyWith(
      registrationProgress: ProgressStatus.loading,
      registrationFailure: null,
    ));
    final result = await _registerNewUser(event.request);
    await result.when(
      success: (user) async {
        final profileFuture =
            sl<ProfileRepository>().fetchUserProfile(user.uid);
        unawaited(_postLoginActions.onEmailPasswordSignInSuccess(user));
        final profile = await profileFuture;
        emit(state.copyWith(
          registrationProgress: ProgressStatus.success,
          lastAuthenticatedUser: user,
          postAuthNavigationRoute: postAuthRouteForProfile(profile),
        ));
      },
      failure: (f) async {
        emit(state.copyWith(
          registrationProgress: ProgressStatus.failure,
          registrationFailure: f,
        ));
      },
    );
  }

  void _onLoginFormOpened(AuthLoginFormOpened event, Emitter<AuthState> emit) {
    emit(state.copyWith(
      loginProgress: ProgressStatus.pure,
      loginFailure: null,
      postAuthNavigationRoute: null,
    ));
  }

  void _onRegistrationFormOpened(
    AuthRegistrationFormOpened event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(
      registrationProgress: ProgressStatus.pure,
      registrationFailure: null,
      postAuthNavigationRoute: null,
    ));
  }

  Future<void> _onIntroGateCheckRequested(
    AuthIntroGateCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      introGateProgress: ProgressStatus.loading,
      introGateFailure: null,
      introShouldSkipToWelcome: null,
    ));
    final result = await _checkIntroCompleted(const NoParams());
    result.when(
      success: (completed) => emit(state.copyWith(
        introGateProgress: ProgressStatus.success,
        introShouldSkipToWelcome: completed,
      )),
      failure: (f) => emit(state.copyWith(
        introGateProgress: ProgressStatus.failure,
        introGateFailure: f,
      )),
    );
  }

  Future<void> _onIntroMarkCompletedRequested(
    AuthIntroMarkCompletedRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(
      introMarkProgress: ProgressStatus.loading,
      introMarkFailure: null,
    ));
    final result = await _markIntroCompleted(const NoParams());
    result.when(
      success: (_) => emit(state.copyWith(
        introMarkProgress: ProgressStatus.success,
      )),
      failure: (f) => emit(state.copyWith(
        introMarkProgress: ProgressStatus.failure,
        introMarkFailure: f,
      )),
    );
  }
}
