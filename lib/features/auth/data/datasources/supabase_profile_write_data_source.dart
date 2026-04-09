import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/new_user_profile_model.dart';

class SupabaseProfileWriteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

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
