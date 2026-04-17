import '../../../../core/common/unit.dart';
import '../../../../core/error/result.dart';
import '../entities/editable_profile_submission.dart';
import '../entities/user_profile.dart';

/// Reads and updates the signed-in user's Firestore profile document.
abstract class ProfileRepository {
  /// Emits `null` if the document is missing; replays the latest snapshot.
  Stream<UserProfile?> watchUserProfile(String userId);

  Future<UserProfile?> fetchUserProfile(String userId);

  /// Deep-merge under `settings` (preserves keys not listed in [settingsPatch]).
  Future<void> mergeUserSettings(
    String userId,
    Map<String, dynamic> settingsPatch,
  );

  /// Top-level merge (avatar URLs, etc.).
  Future<void> mergeUserDocument(
    String userId,
    Map<String, dynamic> patch,
  );

  /// Create / update profile fields from the onboarding / edit form.
  Future<Result<Unit>> submitEditableProfile(EditableProfileSubmission data);
}
