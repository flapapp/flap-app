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
  });

  final ProgressStatus loadProgress;
  final ProgressStatus saveProgress;
  final Failure? loadFailure;
  final Failure? saveFailure;
  final bool notificationsEnabled;
  final bool autoplayVideos;
  final bool showOnlineStatus;
  final bool allowFriendRequests;
}

class ProfileSettingsCubit extends Cubit<ProfileSettingsState> {
  ProfileSettingsCubit(
    this._loadCurrentProfile,
    this._saveAppSettings,
  ) : super(const ProfileSettingsState());

  final LoadCurrentProfileUseCase _loadCurrentProfile;
  final SaveAppSettingsUseCase _saveAppSettings;

  Future<void> load() async {
    emit(
      ProfileSettingsState(
        loadProgress: ProgressStatus.loading,
        saveProgress: state.saveProgress,
        notificationsEnabled: state.notificationsEnabled,
        autoplayVideos: state.autoplayVideos,
        showOnlineStatus: state.showOnlineStatus,
        allowFriendRequests: state.allowFriendRequests,
      ),
    );
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
          ),
        );
      },
      failure: (f) => emit(
        ProfileSettingsState(
          loadProgress: ProgressStatus.failure,
          loadFailure: f,
          notificationsEnabled: state.notificationsEnabled,
          autoplayVideos: state.autoplayVideos,
          showOnlineStatus: state.showOnlineStatus,
          allowFriendRequests: state.allowFriendRequests,
        ),
      ),
    );
  }

  void setNotificationsEnabled(bool v) =>
      emit(_withToggles(notificationsEnabled: v));

  void setAutoplayVideos(bool v) => emit(_withToggles(autoplayVideos: v));

  void setShowOnlineStatus(bool v) => emit(_withToggles(showOnlineStatus: v));

  void setAllowFriendRequests(bool v) =>
      emit(_withToggles(allowFriendRequests: v));

  ProfileSettingsState _withToggles({
    bool? notificationsEnabled,
    bool? autoplayVideos,
    bool? showOnlineStatus,
    bool? allowFriendRequests,
  }) {
    return ProfileSettingsState(
      loadProgress: state.loadProgress,
      saveProgress: state.saveProgress,
      loadFailure: state.loadFailure,
      saveFailure: state.saveFailure,
      notificationsEnabled: notificationsEnabled ?? state.notificationsEnabled,
      autoplayVideos: autoplayVideos ?? state.autoplayVideos,
      showOnlineStatus: showOnlineStatus ?? state.showOnlineStatus,
      allowFriendRequests: allowFriendRequests ?? state.allowFriendRequests,
    );
  }

  Future<void> save() async {
    emit(
      ProfileSettingsState(
        loadProgress: state.loadProgress,
        saveProgress: ProgressStatus.loading,
        loadFailure: state.loadFailure,
        notificationsEnabled: state.notificationsEnabled,
        autoplayVideos: state.autoplayVideos,
        showOnlineStatus: state.showOnlineStatus,
        allowFriendRequests: state.allowFriendRequests,
      ),
    );
    final result = await _saveAppSettings(
      SaveAppSettingsParams(
        notificationsEnabled: state.notificationsEnabled,
        autoplayVideos: state.autoplayVideos,
        showOnlineStatus: state.showOnlineStatus,
        allowFriendRequests: state.allowFriendRequests,
      ),
    );
    result.when(
      success: (_) => emit(
        ProfileSettingsState(
          loadProgress: state.loadProgress,
          saveProgress: ProgressStatus.success,
          loadFailure: state.loadFailure,
          notificationsEnabled: state.notificationsEnabled,
          autoplayVideos: state.autoplayVideos,
          showOnlineStatus: state.showOnlineStatus,
          allowFriendRequests: state.allowFriendRequests,
        ),
      ),
      failure: (f) => emit(
        ProfileSettingsState(
          loadProgress: state.loadProgress,
          saveProgress: ProgressStatus.failure,
          saveFailure: f,
          loadFailure: state.loadFailure,
          notificationsEnabled: state.notificationsEnabled,
          autoplayVideos: state.autoplayVideos,
          showOnlineStatus: state.showOnlineStatus,
          allowFriendRequests: state.allowFriendRequests,
        ),
      ),
    );
  }
}
