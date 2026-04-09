import '../entities/complete_profile_submission.dart';
import '../entities/registration_profile.dart';
import '../entities/user_profile_snapshot.dart';

/// Persists profile fields after email sign-up (Supabase `profiles`).
abstract class UserProfileRepository {
  Future<void> createAfterSignUp({
    required String userId,
    required RegistrationProfile profile,
  });

  Future<bool> isProfileComplete(String userId);

  Future<UserProfileSnapshot?> loadProfile(String userId);

  Future<void> completeProfile({
    required String userId,
    required CompleteProfileSubmission submission,
    String? avatarUrl,
  });
}
