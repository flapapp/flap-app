/// Firebase-backed auth session reads (data layer).
abstract class AuthSessionRemoteDataSource {
  /// Returns Firebase user id after initial auth restoration window, or null.
  Future<String?> resolveInitialUserId();

  /// Current user id if already available (no await).
  String? get currentUserIdOrNull;
}
