/// In-app user preferences loaded from [user_settings].
class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
    this.autoplayVideos = true,
    this.showOnlineStatus = true,
    this.allowFriendRequests = true,
    this.locale = 'en',
  });

  final bool notificationsEnabled;
  final bool autoplayVideos;
  final bool showOnlineStatus;
  final bool allowFriendRequests;
  /// UI language code: `en` or `uk`.
  final String locale;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? autoplayVideos,
    bool? showOnlineStatus,
    bool? allowFriendRequests,
    String? locale,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoplayVideos: autoplayVideos ?? this.autoplayVideos,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      allowFriendRequests: allowFriendRequests ?? this.allowFriendRequests,
      locale: locale ?? this.locale,
    );
  }

  factory AppSettings.fromRemoteRow(Map<String, dynamic>? row) {
    if (row == null || row.isEmpty) {
      return AppSettings.defaults;
    }
    final localeRaw = (row['locale'] ?? 'en').toString();
    final locale = localeRaw == 'ua' ? 'uk' : localeRaw;
    return AppSettings(
      notificationsEnabled: row['notifications_enabled'] != false,
      autoplayVideos: row['autoplay_videos'] != false,
      showOnlineStatus: row['show_online_status'] != false,
      allowFriendRequests: row['allow_friend_requests'] != false,
      locale: locale == 'uk' ? 'uk' : 'en',
    );
  }

  Map<String, dynamic> toSettingsPatch() {
    return <String, dynamic>{
      'notificationsEnabled': notificationsEnabled,
      'autoplayVideos': autoplayVideos,
      'showOnlineStatus': showOnlineStatus,
      'allowFriendRequests': allowFriendRequests,
      'locale': locale,
    };
  }
}
