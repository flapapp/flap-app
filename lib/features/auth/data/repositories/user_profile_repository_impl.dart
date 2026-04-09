import '../../domain/entities/new_user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/supabase_profile_write_data_source.dart';
import '../models/new_user_profile_model.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({required SupabaseProfileWriteDataSource supabase})
      : _supabase = supabase;

  final SupabaseProfileWriteDataSource _supabase;

  @override
  Future<void> createAfterSignUp({
    required String userId,
    required NewUserProfile profile,
    String? avatarUrl,
  }) async {
    final premiumExpiry = DateTime.now().add(const Duration(days: 14));
    final model = NewUserProfileModel.fromEntity(profile);
    await _supabase.updateAfterRegistration(
      userId: userId,
      profile: model,
      avatarUrl: avatarUrl,
      subscriptionExpiry: premiumExpiry,
    );
  }
}
