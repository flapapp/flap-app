import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/complete_profile_submission.dart';
import '../models/new_user_profile_model.dart';
import '../models/registration_profile_model.dart';

class SupabaseProfileWriteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  /// After email sign-up: fill identity and mark profile incomplete.
  Future<void> updateAfterMinimalRegistration({
    required String userId,
    required RegistrationProfileModel profile,
  }) async {
    await _client.from('profiles').update(
          profile.toMinimalSupabasePayload(
            updatedAt: DateTime.now(),
          ),
        ).eq('id', userId);
  }

  /// Loads editable profile fields from `profiles` (read path).
  Future<Map<String, dynamic>?> fetchProfileRow(String userId) async {
    return _client
        .from('profiles')
        .select(
          'name,surname,display_name,email,phone,city,age,position,experience,avatar_url,rating',
        )
        .eq('id', userId)
        .maybeSingle();
  }

  Future<bool> fetchProfileComplete(String userId) async {
    final row = await _client
        .from('profiles')
        .select('profile_complete')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return false;
    return row['profile_complete'] as bool? ?? false;
  }

  Future<void> completeProfile({
    required String userId,
    required CompleteProfileSubmission submission,
    String? avatarUrl,
  }) async {
    final now = DateTime.now();
    final map = <String, dynamic>{
      'name': submission.name,
      'surname': submission.surname,
      'display_name': submission.displayFullName,
      'phone': submission.phone,
      'city': submission.city,
      'age': submission.age,
      'position': submission.position,
      'experience': submission.experience,
      'profile_complete': true,
      'updated_at': now.toUtc().toIso8601String(),
    };
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      map['avatar_url'] = avatarUrl;
    }
    await _client.from('profiles').update(map).eq('id', userId);
  }

  /// Legacy full registration payload (kept for migrations/tests).
  Future<void> updateAfterRegistration({
    required String userId,
    required NewUserProfileModel profile,
    String? avatarUrl,
    required DateTime subscriptionExpiry,
  }) async {
    await _client
        .from('profiles')
        .update(
          profile.toSupabaseUpdatePayload(
            avatarUrl: avatarUrl,
            subscriptionExpiry: subscriptionExpiry,
            updatedAt: DateTime.now(),
          ),
        )
        .eq('id', userId);
  }
}
