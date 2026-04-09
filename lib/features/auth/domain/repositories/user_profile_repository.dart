import '../entities/new_user_profile.dart';

/// Persists profile fields after email sign-up (Supabase `profiles`).
abstract class UserProfileRepository {
  Future<void> createAfterSignUp({
    required String userId,
    required NewUserProfile profile,
    String? avatarUrl,
  });
}
