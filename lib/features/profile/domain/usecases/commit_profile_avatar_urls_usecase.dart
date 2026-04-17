import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../repositories/profile_repository.dart';

class CommitProfileAvatarUrlsParams {
  const CommitProfileAvatarUrlsParams({required this.downloadUrl});

  final String downloadUrl;
}

class CommitProfileAvatarUrlsUseCase
    implements UseCase<Result<Unit>, CommitProfileAvatarUrlsParams> {
  CommitProfileAvatarUrlsUseCase(this._authSession, this._profileRepository);

  final AuthSessionRepository _authSession;
  final ProfileRepository _profileRepository;

  @override
  Future<Result<Unit>> call(CommitProfileAvatarUrlsParams params) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      return const Result.failure(
        Failure.auth(code: 'unauthenticated', message: null),
      );
    }
    try {
      await _profileRepository.mergeUserDocument(uid, <String, dynamic>{
        'avatar': params.downloadUrl,
        'avatarUrl': params.downloadUrl,
      });
      return const Result.success(Unit.value);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
