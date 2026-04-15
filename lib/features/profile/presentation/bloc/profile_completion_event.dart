import 'package:equatable/equatable.dart';

import '../../domain/entities/profile_completion_submission.dart';

abstract class ProfileCompletionEvent extends Equatable {
  const ProfileCompletionEvent();

  @override
  List<Object?> get props => const [];
}

class ProfileCompletionLoadRequested extends ProfileCompletionEvent {
  const ProfileCompletionLoadRequested(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class ProfileCompletionSubmitRequested extends ProfileCompletionEvent {
  const ProfileCompletionSubmitRequested({
    required this.userId,
    required this.submission,
    this.avatarBytes,
    this.avatarMimeType,
  });

  final String userId;
  final ProfileCompletionSubmission submission;
  final List<int>? avatarBytes;
  final String? avatarMimeType;

  @override
  List<Object?> get props => [userId, submission, avatarBytes, avatarMimeType];
}

class ProfileCompletionTransientCleared extends ProfileCompletionEvent {
  const ProfileCompletionTransientCleared();
}
