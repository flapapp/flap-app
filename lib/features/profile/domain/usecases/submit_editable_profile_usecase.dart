import '../../../../core/common/unit.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/editable_profile_submission.dart';
import '../repositories/profile_repository.dart';

class SubmitEditableProfileUseCase
    implements UseCase<Result<Unit>, EditableProfileSubmission> {
  SubmitEditableProfileUseCase(this._profileRepository);

  final ProfileRepository _profileRepository;

  @override
  Future<Result<Unit>> call(EditableProfileSubmission params) {
    return _profileRepository.submitEditableProfile(params);
  }
}
