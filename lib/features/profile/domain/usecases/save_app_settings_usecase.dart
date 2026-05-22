import 'dart:developer' as developer;

import '../../../../core/common/unit.dart';
import '../../../profile/data/services/user_settings_service.dart';
import '../../../../core/di/injection.dart';
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
    required this.locale,
  });

  final bool notificationsEnabled;
  final bool autoplayVideos;
  final bool showOnlineStatus;
  final bool allowFriendRequests;
  final String locale;
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
      developer.log(
        'Saving settings for $uid: locale=${params.locale}, '
        'notifications=${params.notificationsEnabled}, '
        'autoplay=${params.autoplayVideos}',
        name: 'SaveAppSettingsUseCase',
      );
      await _profileRepository.mergeUserSettings(uid, <String, dynamic>{
        'notificationsEnabled': params.notificationsEnabled,
        'autoplayVideos': params.autoplayVideos,
        'showOnlineStatus': params.showOnlineStatus,
        'allowFriendRequests': params.allowFriendRequests,
        'locale': params.locale,
      });
      if (sl.isRegistered<UserSettingsService>()) {
        sl<UserSettingsService>().invalidateCache();
      }
      developer.log('Settings saved', name: 'SaveAppSettingsUseCase');
      return const Result.success(Unit.value);
    } catch (e, st) {
      developer.log(
        'Settings save error',
        name: 'SaveAppSettingsUseCase',
        error: e,
        stackTrace: st,
      );
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
