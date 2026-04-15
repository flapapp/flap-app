import '../../domain/entities/complete_profile_submission.dart';
import '../../domain/entities/registration_profile.dart';
import '../../domain/entities/user_profile_snapshot.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/supabase_profile_write_data_source.dart';
import '../models/registration_profile_model.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({required SupabaseProfileWriteDataSource supabase})
      : _supabase = supabase;

  final SupabaseProfileWriteDataSource _supabase;

  @override
  Future<void> createAfterSignUp({
    required String userId,
    required RegistrationProfile profile,
  }) async {
    final model = RegistrationProfileModel.fromEntity(profile);
    await _supabase.updateAfterMinimalRegistration(
      userId: userId,
      profile: model,
    );
  }

  @override
  Future<bool> isProfileComplete(String userId) {
    return _supabase.fetchProfileComplete(userId);
  }

  @override
  Future<UserProfileSnapshot?> loadProfile(String userId) async {
    final row = await _supabase.fetchProfileRow(userId);
    if (row == null) return null;
    return UserProfileSnapshot.fromSupabaseRow(row);
  }

  @override
  Future<void> completeProfile({
    required String userId,
    required CompleteProfileSubmission submission,
    String? avatarUrl,
  }) async {
    await _supabase.completeProfile(
      userId: userId,
      submission: submission,
      avatarUrl: avatarUrl,
    );
  }

  @override
  Future<void> setAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) {
    return _supabase.setAvatarUrl(userId: userId, avatarUrl: avatarUrl);
  }
}
