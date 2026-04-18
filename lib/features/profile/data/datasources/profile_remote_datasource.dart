/// Firestore `users` collection access (implementation detail).
abstract class ProfileRemoteDataSource {
  /// `null` when the document does not exist.
  Stream<Map<String, dynamic>?> watchUserDocument(String userId);

  Future<Map<String, dynamic>?> getUserDocument(String userId);

  /// Merges [settingsPatch] into existing `settings` without dropping other keys.
  Future<void> mergeUserSettings(
    String userId,
    Map<String, dynamic> settingsPatch,
  );

  /// Top-level merge for fields like `avatar`, `coins`, etc.
  Future<void> mergeUserDocument(
    String userId,
    Map<String, dynamic> patch,
  );

  /// Best-effort demo friend links (legacy onboarding behaviour).
  Future<void> trySeedDemoCrossFriends(String userId);

  /// Batch-read user docs (chunked `whereIn` for Firestore limits).
  Future<Map<String, Map<String, dynamic>>> getUserDocumentsByIds(
    List<String> userIds,
  );
}
