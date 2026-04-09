import '../../domain/entities/new_user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import '../datasources/supabase_profile_write_data_source.dart';

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
    await _supabase.updateAfterRegistration(
      userId: userId,
      profile: profile,
      avatarUrl: avatarUrl,
      subscriptionExpiry: premiumExpiry,
    );
  }
}
