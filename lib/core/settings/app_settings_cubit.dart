import 'dart:async';
import 'dart:developer' as developer;

import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../app_navigator_key.dart';
import '../../core/error/failure.dart';
import '../../core/progress/progress_status.dart';
import '../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../features/notifications/data/services/notification_service.dart';
import '../../features/profile/data/services/user_settings_service.dart';
import '../../features/profile/domain/usecases/save_app_settings_usecase.dart';
import '../../features/profile/presentation/bloc/profile_bloc.dart';
import '../di/injection.dart';
import 'app_settings.dart';

class AppSettingsState {
  const AppSettingsState({
    this.loadProgress = ProgressStatus.pure,
    this.saveProgress = ProgressStatus.pure,
    this.loadFailure,
    this.saveFailure,
    this.settings = AppSettings.defaults,
    this.draft,
  });

  final ProgressStatus loadProgress;
  final ProgressStatus saveProgress;
  final Failure? loadFailure;
  final Failure? saveFailure;
  final AppSettings settings;
  final AppSettings? draft;

  AppSettings get effective => draft ?? settings;

  AppSettingsState copyWith({
    ProgressStatus? loadProgress,
    ProgressStatus? saveProgress,
    Failure? loadFailure,
    Failure? saveFailure,
    AppSettings? settings,
    AppSettings? draft,
    bool clearDraft = false,
  }) {
    return AppSettingsState(
      loadProgress: loadProgress ?? this.loadProgress,
      saveProgress: saveProgress ?? this.saveProgress,
      loadFailure: loadFailure,
      saveFailure: saveFailure,
      settings: settings ?? this.settings,
      draft: clearDraft ? null : (draft ?? this.draft),
    );
  }
}

/// Global app settings: loads from Supabase, keeps draft while editing, applies on save.
class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit(
    this._authSession,
    this._userSettings,
    this._saveAppSettings,
  ) : super(const AppSettingsState());

  final AuthSessionRepository _authSession;
  final UserSettingsService _userSettings;
  final SaveAppSettingsUseCase _saveAppSettings;

  Future<void> load({bool forceRefresh = false}) async {
    if (_authSession.peekCurrentUser?.uid == null) {
      emit(
        state.copyWith(
          loadProgress: ProgressStatus.success,
          settings: AppSettings.defaults,
          clearDraft: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        loadProgress: ProgressStatus.loading,
        loadFailure: null,
      ),
    );

    try {
      final loaded = await _userSettings.getSettings(forceRefresh: forceRefresh);
      emit(
        state.copyWith(
          loadProgress: ProgressStatus.success,
          settings: loaded,
          clearDraft: true,
        ),
      );
      await applyLocale(loaded.locale);
    } catch (e, st) {
      developer.log(
        'AppSettingsCubit.load failed',
        name: 'AppSettingsCubit',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          loadProgress: ProgressStatus.failure,
          loadFailure: Failure.unexpected(e.toString()),
        ),
      );
    }
  }

  void reset() {
    _userSettings.invalidateCache();
    emit(const AppSettingsState());
  }

  void setNotificationsEnabled(bool value) =>
      _patchDraft(notificationsEnabled: value);

  void setAutoplayVideos(bool value) => _patchDraft(autoplayVideos: value);

  void setShowOnlineStatus(bool value) => _patchDraft(showOnlineStatus: value);

  void setAllowFriendRequests(bool value) =>
      _patchDraft(allowFriendRequests: value);

  /// Switches the app language. Unlike the other preference setters (which only
  /// stage a draft until [save] is pressed), language applies *live* the moment
  /// it is selected — so it is also persisted immediately. Otherwise the next
  /// [load] (e.g. re-opening Settings) would clear the unsaved draft and revert
  /// to the stored value.
  Future<void> setLocale(String locale) async {
    final code = locale == 'uk' ? 'uk' : 'en';
    if (state.effective.locale == code) return;

    // Commit onto the saved settings (and mirror into any active draft so the
    // selector highlights correctly and a later Save won't re-revert locale).
    emit(
      state.copyWith(
        settings: state.settings.copyWith(locale: code),
        draft: state.draft?.copyWith(locale: code),
      ),
    );

    await applyLocale(code);

    // Persist just the locale change. Other pending draft toggles are NOT
    // flushed here: we write the committed values for them plus the new locale.
    final base = state.settings;
    final result = await _saveAppSettings(
      SaveAppSettingsParams(
        notificationsEnabled: base.notificationsEnabled,
        autoplayVideos: base.autoplayVideos,
        showOnlineStatus: base.showOnlineStatus,
        allowFriendRequests: base.allowFriendRequests,
        locale: code,
      ),
    );
    result.when(
      success: (_) => _userSettings.invalidateCache(),
      failure: (f) => developer.log(
        'Locale persist failed: $f',
        name: 'AppSettingsCubit',
      ),
    );
  }

  void _patchDraft({
    bool? notificationsEnabled,
    bool? autoplayVideos,
    bool? showOnlineStatus,
    bool? allowFriendRequests,
    String? locale,
  }) {
    final base = state.effective;
    emit(
      state.copyWith(
        draft: base.copyWith(
          notificationsEnabled: notificationsEnabled,
          autoplayVideos: autoplayVideos,
          showOnlineStatus: showOnlineStatus,
          allowFriendRequests: allowFriendRequests,
          locale: locale,
        ),
      ),
    );
  }

  Future<void> save() async {
    final toSave = state.effective;
    emit(state.copyWith(saveProgress: ProgressStatus.loading, saveFailure: null));

    final result = await _saveAppSettings(
      SaveAppSettingsParams(
        notificationsEnabled: toSave.notificationsEnabled,
        autoplayVideos: toSave.autoplayVideos,
        showOnlineStatus: toSave.showOnlineStatus,
        allowFriendRequests: toSave.allowFriendRequests,
        locale: toSave.locale,
      ),
    );

    await result.when(
      success: (_) => _onSaveSuccess(),
      failure: (f) async {
        developer.log(
          'Settings save failed: $f',
          name: 'AppSettingsCubit',
        );
        emit(
          state.copyWith(
            saveProgress: ProgressStatus.failure,
            saveFailure: f,
          ),
        );
      },
    );
  }

  Future<void> _onSaveSuccess() async {
    _userSettings.invalidateCache();
    final refreshed = await _userSettings.getSettings(forceRefresh: true);
    emit(
      state.copyWith(
        saveProgress: ProgressStatus.success,
        settings: refreshed,
        clearDraft: true,
      ),
    );
    await applyLocale(refreshed.locale);
    try {
      if (refreshed.notificationsEnabled) {
        await sl<NotificationService>().syncCurrentUserToken();
      } else {
        await sl<NotificationService>().initialize();
      }
    } catch (e, st) {
      developer.log(
        'Notification sync after settings save failed',
        name: 'AppSettingsCubit',
        error: e,
        stackTrace: st,
      );
    }
    try {
      sl<ProfileBloc>().add(const ProfileEvent.userProfileSyncRequested());
    } catch (_) {}
    developer.log('Settings saved successfully', name: 'AppSettingsCubit');
  }

  Future<void> applyLocale(String languageCode) async {
    final code = languageCode == 'uk' ? 'uk' : 'en';
    final locale = Locale(code);
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) {
      developer.log(
        'applyLocale skipped: navigator context not ready ($code)',
        name: 'AppSettingsCubit',
      );
      return;
    }
    if (ctx.locale.languageCode == code) {
      return;
    }
    await ctx.setLocale(locale);
    developer.log('Locale applied: $code', name: 'AppSettingsCubit');
  }
}
