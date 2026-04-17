import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/profile_repository.dart';

class DismissDonationPromptParams {
  const DismissDonationPromptParams({required this.userId});

  final String userId;
}

/// Persists `settings.hideDonationPrompt` for the given user.
class DismissDonationPromptUseCase
    implements UseCase<Result<Unit>, DismissDonationPromptParams> {
  DismissDonationPromptUseCase(this._profileRepository);

  final ProfileRepository _profileRepository;

  @override
  Future<Result<Unit>> call(DismissDonationPromptParams params) async {
    try {
      await _profileRepository.mergeUserSettings(
        params.userId,
        const {'hideDonationPrompt': true},
      );
      return const Result.success(Unit.value);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
