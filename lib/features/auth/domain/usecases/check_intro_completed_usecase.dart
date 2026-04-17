import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/intro_settings_repository.dart';

class CheckIntroCompletedUseCase implements UseCase<Result<bool>, NoParams> {
  CheckIntroCompletedUseCase(this._introSettingsRepository);

  final IntroSettingsRepository _introSettingsRepository;

  @override
  Future<Result<bool>> call(NoParams params) async {
    try {
      final done = await _introSettingsRepository.isIntroCompleted();
      return Result.success(done);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
