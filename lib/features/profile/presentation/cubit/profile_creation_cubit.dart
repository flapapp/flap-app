import 'package:bloc/bloc.dart';

import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/progress/progress_status.dart';
import '../../domain/entities/editable_profile_submission.dart';
import '../../domain/usecases/submit_editable_profile_usecase.dart';

class ProfileCreationState {
  const ProfileCreationState({
    this.submitProgress = ProgressStatus.pure,
    this.submitFailure,
  });

  final ProgressStatus submitProgress;
  final Failure? submitFailure;
}

class ProfileCreationCubit extends Cubit<ProfileCreationState> {
  ProfileCreationCubit(this._submitEditableProfile)
      : super(const ProfileCreationState());

  final SubmitEditableProfileUseCase _submitEditableProfile;

  Future<Result<Unit>> submit(EditableProfileSubmission data) async {
    emit(const ProfileCreationState(submitProgress: ProgressStatus.loading));
    final result = await _submitEditableProfile(data);
    result.when(
      success: (_) => emit(
        const ProfileCreationState(
          submitProgress: ProgressStatus.success,
        ),
      ),
      failure: (f) => emit(
        ProfileCreationState(
          submitProgress: ProgressStatus.failure,
          submitFailure: f,
        ),
      ),
    );
    return result;
  }
}

