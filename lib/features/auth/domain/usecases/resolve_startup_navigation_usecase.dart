import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/startup_destination.dart';
import '../repositories/auth_session_repository.dart';
import '../repositories/intro_settings_repository.dart';

class ResolveStartupNavigationUseCase
    implements UseCase<Result<StartupDestination>, NoParams> {
  ResolveStartupNavigationUseCase(
    this._authSessionRepository,
    this._introSettingsRepository,
  );

  final AuthSessionRepository _authSessionRepository;
  final IntroSettingsRepository _introSettingsRepository;

  @override
  Future<Result<StartupDestination>> call(NoParams params) async {
    try {
      final user = await _authSessionRepository.resolveInitialSession();
      if (user != null) {
        return const Result.success(StartupDestination.authenticated);
      }
      final introDone = await _introSettingsRepository.isIntroCompleted();
      return Result.success(
        introDone ? StartupDestination.guestWelcome : StartupDestination.guestIntro,
      );
    } catch (e) {
      return Result.failure(
        Failure.unexpected(e.toString()),
      );
    }
  }
}
