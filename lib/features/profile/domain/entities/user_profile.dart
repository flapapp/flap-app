/// User-facing profile snapshot from `users/{uid}` (domain).
class ProfileSettings {
  const ProfileSettings({
    this.hideDonationPrompt = false,
    this.notificationsEnabled = true,
    this.autoplayVideos = true,
    this.showOnlineStatus = true,
    this.allowFriendRequests = true,
  });

  final bool hideDonationPrompt;
  final bool notificationsEnabled;
  final bool autoplayVideos;
  final bool showOnlineStatus;
  final bool allowFriendRequests;

  static ProfileSettings fromFirestoreMap(Map<String, dynamic>? raw) {
    final map = Map<String, dynamic>.from(raw ?? const <String, dynamic>{});
    return ProfileSettings(
      hideDonationPrompt: map['hideDonationPrompt'] == true,
      notificationsEnabled: map['notificationsEnabled'] != false,
      autoplayVideos: map['autoplayVideos'] != false,
      showOnlineStatus: map['showOnlineStatus'] != false,
      allowFriendRequests: map['allowFriendRequests'] != false,
    );
  }
}

/// Full Firestore user document mapped to typed settings + [legacyUserData] for existing UI.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.settings,
    required Map<String, dynamic> document,
  }) : _document = document;

  final String id;
  final ProfileSettings settings;

  final Map<String, dynamic> _document;

  Map<String, dynamic> get document => Map<String, dynamic>.from(_document);

  String get displayName {
    final name = _document['name'] ?? _document['displayName'];
    if (name is String) return name;
    return name?.toString() ?? '';
  }

  String? get avatarUrl =>
      _document['avatar'] as String? ?? _document['avatarUrl'] as String?;

  /// Existing widgets expect a `userData` map including `uid`.
  Map<String, dynamic> get legacyUserData => {
        ...document,
        'uid': id,
      };

  factory UserProfile.fromDocument(String id, Map<String, dynamic> data) {
    final rawSettings = data['settings'];
    final Map<String, dynamic> settingsMap;
    if (rawSettings is Map<String, dynamic>) {
      settingsMap = rawSettings;
    } else if (rawSettings is Map) {
      settingsMap = Map<String, dynamic>.from(rawSettings);
    } else {
      settingsMap = const <String, dynamic>{};
    }
    return UserProfile(
      id: id,
      settings: ProfileSettings.fromFirestoreMap(settingsMap),
      document: Map<String, dynamic>.from(data),
    );
  }
}
