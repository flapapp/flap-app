import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class LoadCurrentProfileUseCase implements UseCase<Result<UserProfile>, NoParams> {
  LoadCurrentProfileUseCase(this._authSession, this._profileRepository);

  final AuthSessionRepository _authSession;
  final ProfileRepository _profileRepository;

  @override
  Future<Result<UserProfile>> call(NoParams params) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      return const Result.failure(
        Failure.auth(code: 'unauthenticated', message: null),
      );
    }
    try {
      final profile = await _profileRepository.fetchUserProfile(uid);
      if (profile == null) {
        return Result.failure(Failure.unexpected('Profile document missing'));
      }
      return Result.success(profile);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
