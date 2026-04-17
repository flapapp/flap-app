import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/intro_settings_repository.dart';

class MarkIntroCompletedUseCase implements UseCase<Result<Unit>, NoParams> {
  MarkIntroCompletedUseCase(this._introSettingsRepository);

  final IntroSettingsRepository _introSettingsRepository;

  @override
  Future<Result<Unit>> call(NoParams params) async {
    try {
      await _introSettingsRepository.markIntroCompleted();
      return const Result.success(Unit.value);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
