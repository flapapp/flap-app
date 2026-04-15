import '../entities/profile_completion_submission.dart';
import '../repositories/profile_repository.dart';

class CompleteProfileUseCase {
  CompleteProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<void> call({
    required String userId,
    required ProfileCompletionSubmission submission,
    String? avatarUrl,
  }) {
    return _repository.completeProfile(
      userId: userId,
      submission: submission,
      avatarUrl: avatarUrl,
    );
  }
}
