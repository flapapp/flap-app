import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../repositories/profile_repository.dart';

class SaveAppSettingsParams {
  const SaveAppSettingsParams({
    required this.notificationsEnabled,
    required this.autoplayVideos,
    required this.showOnlineStatus,
    required this.allowFriendRequests,
  });

  final bool notificationsEnabled;
  final bool autoplayVideos;
  final bool showOnlineStatus;
  final bool allowFriendRequests;
}

/// Persists app preference flags under `users/{uid}.settings` (merged).
class SaveAppSettingsUseCase implements UseCase<Result<Unit>, SaveAppSettingsParams> {
  SaveAppSettingsUseCase(this._authSession, this._profileRepository);

  final AuthSessionRepository _authSession;
  final ProfileRepository _profileRepository;

  @override
  Future<Result<Unit>> call(SaveAppSettingsParams params) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      return const Result.failure(
        Failure.auth(code: 'unauthenticated', message: null),
      );
    }
    try {
      await _profileRepository.mergeUserSettings(uid, <String, dynamic>{
        'notificationsEnabled': params.notificationsEnabled,
        'autoplayVideos': params.autoplayVideos,
        'showOnlineStatus': params.showOnlineStatus,
        'allowFriendRequests': params.allowFriendRequests,
      });
      return const Result.success(Unit.value);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
