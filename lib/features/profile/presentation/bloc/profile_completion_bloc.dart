import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/supabase_avatar_storage.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/complete_profile_usecase.dart';
import '../../domain/usecases/fetch_profile_completion_snapshot_usecase.dart';
import 'profile_completion_event.dart';
import 'profile_completion_state.dart';

class ProfileCompletionBloc
    extends Bloc<ProfileCompletionEvent, ProfileCompletionState> {
  ProfileCompletionBloc({
    required ProfileRepository repository,
  })  : _repository = repository,
        _fetchSnapshot = FetchProfileCompletionSnapshotUseCase(repository),
        _completeProfile = CompleteProfileUseCase(repository),
        super(const ProfileCompletionState()) {
    on<ProfileCompletionLoadRequested>(_onLoadRequested);
    on<ProfileCompletionSubmitRequested>(_onSubmitRequested);
    on<ProfileCompletionTransientCleared>(_onTransientCleared);
  }

  final ProfileRepository _repository;
  final FetchProfileCompletionSnapshotUseCase _fetchSnapshot;
  final CompleteProfileUseCase _completeProfile;

  Future<void> _onLoadRequested(
    ProfileCompletionLoadRequested event,
    Emitter<ProfileCompletionState> emit,
  ) async {
    emit(
      state.copyWith(
        loading: true,
        clearErrorMessage: true,
        clearInfoMessage: true,
      ),
    );
    try {
      final snapshot = await _fetchSnapshot(event.userId);
      emit(
        state.copyWith(
          loading: false,
          snapshot: snapshot,
          submitSucceeded: false,
          clearAvatarUrl: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: e.toString(),
          submitSucceeded: false,
          clearAvatarUrl: true,
        ),
      );
    }
  }

  Future<void> _onSubmitRequested(
    ProfileCompletionSubmitRequested event,
    Emitter<ProfileCompletionState> emit,
  ) async {
    emit(
      state.copyWith(
        submitting: true,
        submitSucceeded: false,
        clearErrorMessage: true,
        clearInfoMessage: true,
        clearAvatarUrl: true,
      ),
    );

    try {
      await _completeProfile(
        userId: event.userId,
        submission: event.submission,
        avatarUrl: null,
      );
    } catch (e) {
      emit(
        state.copyWith(
          submitting: false,
          errorMessage: 'Could not save profile: $e',
          submitSucceeded: false,
        ),
      );
      return;
    }

    String? avatarUrl;
    String? infoMessage;
    if (event.avatarBytes != null) {
      try {
        avatarUrl = await SupabaseAvatarStorage.uploadAvatar(
          userId: event.userId,
          bytes: Uint8List.fromList(event.avatarBytes!),
          mimeTypeFromPicker: event.avatarMimeType,
        );
      } catch (e) {
        infoMessage = 'Profile saved, but photo upload failed: $e';
      }

      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        try {
          await _repository.setAvatarUrl(
            userId: event.userId,
            avatarUrl: avatarUrl,
          );
        } catch (e) {
          infoMessage = 'Photo uploaded, but saving the link failed: $e';
          avatarUrl = null;
        }
      }
    }

    emit(
      state.copyWith(
        submitting: false,
        submitSucceeded: true,
        avatarUrl: avatarUrl,
        infoMessage: infoMessage,
        clearErrorMessage: true,
      ),
    );
  }

  void _onTransientCleared(
    ProfileCompletionTransientCleared event,
    Emitter<ProfileCompletionState> emit,
  ) {
    emit(
      state.copyWith(
        clearErrorMessage: true,
        clearInfoMessage: true,
        submitSucceeded: false,
        clearAvatarUrl: true,
      ),
    );
  }
}
