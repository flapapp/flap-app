import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/new_user_profile.dart';

class SupabaseProfileWriteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> updateAfterRegistration({
    required String userId,
    required NewUserProfile profile,
    String? avatarUrl,
    required DateTime subscriptionExpiry,
  }) async {
    await _client.from('profiles').update({
      'display_name': profile.displayFullName,
      'name': profile.name,
      'surname': profile.surname,
      'email': profile.email,
      'phone': profile.phone,
      'city': profile.city,
      'age': profile.age,
      'position': profile.position,
      'experience': profile.experience,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'rating': 3.0,
      'match_rating': 3.0,
      'video_rating': 3.0,
      'total_matches': 0,
      'total_videos': 0,
      'rating_history': <dynamic>[],
      'coins': 160,
      'matches': 0,
      'goals': 0,
      'assists': 0,
      'subscription': 'champions_league',
      'subscription_expiry': subscriptionExpiry.toIso8601String(),
      'subscription_active': true,
      'challenges_created': 0,
      'max_challenges_per_month': 999,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
