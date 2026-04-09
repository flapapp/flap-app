import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';

/// Reads notification / playback preferences from `profiles.settings` (Supabase).
class UserSettingsService {
  UserSettingsService({ProfileRepository? repository}) : _override = repository;

  static ProfileRepository? _globalRepository;
  final ProfileRepository? _override;

  /// Called from [main] after [ProfileRepository] is constructed.
  static void registerGlobalRepository(ProfileRepository repository) {
    _globalRepository = repository;
  }

  ProfileRepository? get _repo => _override ?? _globalRepository;

  Future<Map<String, dynamic>> getCurrentSettings() async {
    final uid = AppAuthContext.userId;
    final repo = _repo;
    if (uid == null || repo == null) return const {};

    try {
      return repo.fetchSettings(uid);
    } catch (_) {
      return const {};
    }
  }

  Future<bool> isNotificationsEnabled() async {
    final settings = await getCurrentSettings();
    return settings['notificationsEnabled'] ?? true;
  }

  Future<bool> isAutoplayEnabled() async {
    final settings = await getCurrentSettings();
    return settings['autoplayVideos'] ?? true;
  }
}
