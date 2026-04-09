/// Profile feature: Supabase-backed replacement for Firestore `users/{uid}` reads
/// and `settings` writes.
abstract class ProfileRepository {
  Stream<Map<String, dynamic>> watchLegacyUserMap(String userId);

  Future<Map<String, dynamic>?> fetchLegacyUserMap(String userId);

  Future<Map<String, dynamic>> fetchSettings(String userId);

  Future<void> mergeSettings(String userId, Map<String, dynamic> partial);
}
