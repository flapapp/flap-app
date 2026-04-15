import 'package:equatable/equatable.dart';

import '../../domain/entities/profile_completion_snapshot.dart';

class ProfileCompletionState extends Equatable {
  const ProfileCompletionState({
    this.loading = false,
    this.submitting = false,
    this.snapshot,
    this.errorMessage,
    this.infoMessage,
    this.submitSucceeded = false,
    this.avatarUrl,
  });

  final bool loading;
  final bool submitting;
  final ProfileCompletionSnapshot? snapshot;
  final String? errorMessage;
  final String? infoMessage;
  final bool submitSucceeded;
  final String? avatarUrl;

  ProfileCompletionState copyWith({
    bool? loading,
    bool? submitting,
    ProfileCompletionSnapshot? snapshot,
    bool clearSnapshot = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? infoMessage,
    bool clearInfoMessage = false,
    bool? submitSucceeded,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) {
    return ProfileCompletionState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfoMessage ? null : (infoMessage ?? this.infoMessage),
      submitSucceeded: submitSucceeded ?? this.submitSucceeded,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    );
  }

  @override
  List<Object?> get props => [
        loading,
        submitting,
        snapshot,
        errorMessage,
        infoMessage,
        submitSucceeded,
        avatarUrl,
      ];
}
