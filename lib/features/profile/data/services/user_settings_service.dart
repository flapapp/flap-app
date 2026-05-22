import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../../core/di/injection.dart';

/// Loads and caches the signed-in user's [user_settings] row.
class UserSettingsService {
  UserSettingsService(this._authSession);

  final AuthSessionRepository _authSession;
  SupabaseClient get _client => Supabase.instance.client;

  AppSettings? _cache;
  DateTime? _cacheLoadedAt;

  AppSettings? get cached => _cache;

  bool get notificationsEnabled =>
      _cache?.notificationsEnabled ?? AppSettings.defaults.notificationsEnabled;

  bool get autoplayVideos =>
      _cache?.autoplayVideos ?? AppSettings.defaults.autoplayVideos;

  void invalidateCache() {
    _cache = null;
    _cacheLoadedAt = null;
    developer.log('App settings cache cleared', name: 'UserSettingsService');
  }

  Future<AppSettings> getSettings({bool forceRefresh = false}) async {
    if (_cache != null && !forceRefresh) {
      return _cache!;
    }
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      developer.log(
        'No signed-in user; returning default settings',
        name: 'UserSettingsService',
      );
      _cache = AppSettings.defaults;
      return _cache!;
    }

    try {
      developer.log(
        'Loading settings for $uid (force=$forceRefresh)',
        name: 'UserSettingsService',
      );
      final row = await _client
          .from('user_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      final settings = AppSettings.fromRemoteRow(
        row == null ? null : Map<String, dynamic>.from(row),
      );
      _cache = settings;
      _cacheLoadedAt = DateTime.now();
      developer.log(
        'Settings loaded: locale=${settings.locale}, '
        'notifications=${settings.notificationsEnabled}, '
        'autoplay=${settings.autoplayVideos}',
        name: 'UserSettingsService',
      );
      return settings;
    } catch (e, st) {
      developer.log(
        'Failed to load settings',
        name: 'UserSettingsService',
        error: e,
        stackTrace: st,
      );
      if (_cache != null) {
        return _cache!;
      }
      _cache = AppSettings.defaults;
      return _cache!;
    }
  }

  Future<bool> isNotificationsEnabled() async {
    return (await getSettings()).notificationsEnabled;
  }

  Future<bool> isAutoplayEnabled() async {
    return (await getSettings()).autoplayVideos;
  }

  DateTime? get cacheLoadedAt => _cacheLoadedAt;
}
