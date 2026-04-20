import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/commit_profile_avatar_urls_usecase.dart';
import '../../domain/usecases/dismiss_donation_prompt_usecase.dart';

part 'profile_bloc.freezed.dart';

@freezed
class ProfileEvent with _$ProfileEvent {
  const factory ProfileEvent.started() = ProfileStarted;

  const factory ProfileEvent.donationPromptDismissRequested() =
      ProfileDonationPromptDismissRequested;

  const factory ProfileEvent.avatarCommitted({required String downloadUrl}) =
      ProfileAvatarCommitted;
}

@freezed
class ProfileState with _$ProfileState {
  const factory ProfileState({
    @Default(ProgressStatus.pure) ProgressStatus streamProgress,
    UserProfile? profile,
    Failure? streamFailure,
    @Default(ProgressStatus.pure) ProgressStatus dismissDonationProgress,
    Failure? dismissDonationFailure,
    @Default(ProgressStatus.pure) ProgressStatus avatarCommitProgress,
    Failure? avatarCommitFailure,
  }) = _ProfileState;
}

/// Observes the current user's Firestore profile and exposes donation-prompt actions.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(
    this._authSession,
    this._profileRepository,
    this._dismissDonationPrompt,
    this._commitAvatarUrls,
  ) : super(const ProfileState()) {
    on<ProfileStarted>(_onStarted);
    on<ProfileDonationPromptDismissRequested>(_onDismissDonation);
    on<ProfileAvatarCommitted>(_onAvatarCommitted);
  }

  final AuthSessionRepository _authSession;
  final ProfileRepository _profileRepository;
  final DismissDonationPromptUseCase _dismissDonationPrompt;
  final CommitProfileAvatarUrlsUseCase _commitAvatarUrls;

  Future<void> _onStarted(
    ProfileStarted event,
    Emitter<ProfileState> emit,
  ) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      emit(
        state.copyWith(
          streamProgress: ProgressStatus.failure,
          streamFailure: const Failure.auth(
            code: 'unauthenticated',
            message: null,
          ),
          profile: null,
        ),
      );
      return;
    }
    // Reuse in-memory profile when reopening the profile tab (same user, last load OK).
    if (state.profile != null &&
        state.profile!.id == uid &&
        state.streamProgress == ProgressStatus.success) {
      return;
    }
    emit(
      state.copyWith(
        streamProgress: ProgressStatus.loading,
        streamFailure: null,
      ),
    );
    try {
      final profile = await _profileRepository.fetchUserProfile(uid);
      emit(
        state.copyWith(
          streamProgress: ProgressStatus.success,
          profile: profile,
          streamFailure: null,
          avatarCommitFailure: null,
          avatarCommitProgress: ProgressStatus.pure,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          streamProgress: ProgressStatus.failure,
          streamFailure: Failure.unexpected(e.toString()),
        ),
      );
    }
  }

  Future<void> _onDismissDonation(
    ProfileDonationPromptDismissRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      emit(
        state.copyWith(
          dismissDonationProgress: ProgressStatus.failure,
          dismissDonationFailure: const Failure.auth(
            code: 'unauthenticated',
            message: null,
          ),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        dismissDonationProgress: ProgressStatus.loading,
        dismissDonationFailure: null,
      ),
    );
    final result = await _dismissDonationPrompt(
      DismissDonationPromptParams(userId: uid),
    );
    result.when(
      success: (_) => emit(
        state.copyWith(
          dismissDonationProgress: ProgressStatus.success,
          dismissDonationFailure: null,
        ),
      ),
      failure: (f) => emit(
        state.copyWith(
          dismissDonationProgress: ProgressStatus.failure,
          dismissDonationFailure: f,
        ),
      ),
    );
  }

  Future<void> _onAvatarCommitted(
    ProfileAvatarCommitted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(
      state.copyWith(
        avatarCommitProgress: ProgressStatus.loading,
        avatarCommitFailure: null,
      ),
    );
    final result = await _commitAvatarUrls(
      CommitProfileAvatarUrlsParams(downloadUrl: event.downloadUrl),
    );
    await result.when(
      success: (_) async {
        final uid = _authSession.peekCurrentUser?.uid;
        UserProfile? updated;
        if (uid != null) {
          updated = await _profileRepository.fetchUserProfile(uid);
        }
        emit(
          state.copyWith(
            avatarCommitProgress: ProgressStatus.success,
            avatarCommitFailure: null,
            profile: updated ?? state.profile,
          ),
        );
      },
      failure: (f) async {
        emit(
          state.copyWith(
            avatarCommitProgress: ProgressStatus.failure,
            avatarCommitFailure: f,
          ),
        );
      },
    );
  }
}
