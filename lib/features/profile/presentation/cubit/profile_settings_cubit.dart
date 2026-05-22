import 'package:bloc/bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/progress/progress_status.dart';
import '../../../../core/usecases/no_params.dart';
import '../../domain/usecases/load_current_profile_usecase.dart';
import '../../domain/usecases/save_app_settings_usecase.dart';

class ProfileSettingsState {
  const ProfileSettingsState({
    this.loadProgress = ProgressStatus.pure,
    this.saveProgress = ProgressStatus.pure,
    this.loadFailure,
    this.saveFailure,
    this.notificationsEnabled = true,
    this.autoplayVideos = true,
    this.showOnlineStatus = true,
    this.allowFriendRequests = true,
    this.locale = 'en',
  });

  final ProgressStatus loadProgress;
  final ProgressStatus saveProgress;
  final Failure? loadFailure;
  final Failure? saveFailure;
  final bool notificationsEnabled;
  final bool autoplayVideos;
  final bool showOnlineStatus;
  final bool allowFriendRequests;
  final String locale;
}

class ProfileSettingsCubit extends Cubit<ProfileSettingsState> {
  ProfileSettingsCubit(
    this._loadCurrentProfile,
    this._saveAppSettings,
  ) : super(const ProfileSettingsState());

  final LoadCurrentProfileUseCase _loadCurrentProfile;
  final SaveAppSettingsUseCase _saveAppSettings;

  Future<void> load() async {
    emit(_copy(loadProgress: ProgressStatus.loading));
    final result = await _loadCurrentProfile(const NoParams());
    result.when(
      success: (profile) {
        final s = profile.settings;
        emit(
          ProfileSettingsState(
            loadProgress: ProgressStatus.success,
            notificationsEnabled: s.notificationsEnabled,
            autoplayVideos: s.autoplayVideos,
            showOnlineStatus: s.showOnlineStatus,
            allowFriendRequests: s.allowFriendRequests,
            locale: s.locale,
          ),
        );
      },
      failure: (f) => emit(
        _copy(
          loadProgress: ProgressStatus.failure,
          loadFailure: f,
        ),
      ),
    );
  }

  void setNotificationsEnabled(bool v) =>
      emit(_copy(notificationsEnabled: v));

  void setAutoplayVideos(bool v) => emit(_copy(autoplayVideos: v));

  void setShowOnlineStatus(bool v) => emit(_copy(showOnlineStatus: v));

  void setAllowFriendRequests(bool v) => emit(_copy(allowFriendRequests: v));

  void setLocale(String locale) {
    final code = locale == 'uk' ? 'uk' : 'en';
    emit(_copy(locale: code));
  }

  Future<void> save() async {
    emit(_copy(saveProgress: ProgressStatus.loading));
    final result = await _saveAppSettings(
      SaveAppSettingsParams(
        notificationsEnabled: state.notificationsEnabled,
        autoplayVideos: state.autoplayVideos,
        showOnlineStatus: state.showOnlineStatus,
        allowFriendRequests: state.allowFriendRequests,
        locale: state.locale,
      ),
    );
    result.when(
      success: (_) => emit(
        _copy(saveProgress: ProgressStatus.success),
      ),
      failure: (f) => emit(
        _copy(
          saveProgress: ProgressStatus.failure,
          saveFailure: f,
        ),
      ),
    );
  }

  ProfileSettingsState _copy({
    ProgressStatus? loadProgress,
    ProgressStatus? saveProgress,
    Failure? loadFailure,
    Failure? saveFailure,
    bool? notificationsEnabled,
    bool? autoplayVideos,
    bool? showOnlineStatus,
    bool? allowFriendRequests,
    String? locale,
  }) {
    return ProfileSettingsState(
      loadProgress: loadProgress ?? state.loadProgress,
      saveProgress: saveProgress ?? state.saveProgress,
      loadFailure: loadFailure ?? state.loadFailure,
      saveFailure: saveFailure ?? state.saveFailure,
      notificationsEnabled: notificationsEnabled ?? state.notificationsEnabled,
      autoplayVideos: autoplayVideos ?? state.autoplayVideos,
      showOnlineStatus: showOnlineStatus ?? state.showOnlineStatus,
      allowFriendRequests: allowFriendRequests ?? state.allowFriendRequests,
      locale: locale ?? state.locale,
    );
  }
}
