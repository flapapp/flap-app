import '../entities/profile_completion_snapshot.dart';
import '../entities/profile_completion_submission.dart';

/// Profile feature: Supabase-backed replacement for Firestore `users/{uid}` reads
/// and `settings` writes.
abstract class ProfileRepository {
  Stream<Map<String, dynamic>> watchLegacyUserMap(String userId);

  Future<Map<String, dynamic>?> fetchLegacyUserMap(String userId);

  Future<Map<String, dynamic>> fetchSettings(String userId);

  Future<void> mergeSettings(String userId, Map<String, dynamic> partial);

  Stream<List<Map<String, dynamic>>> watchWalletTransactions(String userId);

  Future<ProfileCompletionSnapshot?> fetchCompletionSnapshot(String userId);

  Future<void> completeProfile({
    required String userId,
    required ProfileCompletionSubmission submission,
    String? avatarUrl,
  });

  Future<void> setAvatarUrl({
    required String userId,
    required String avatarUrl,
  });
}
