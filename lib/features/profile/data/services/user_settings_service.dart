import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/repositories/auth_session_repository.dart';
import '../../../../core/di/injection.dart';

class UserSettingsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>> getCurrentSettings() async {
    final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
    if (uid == null) {
      return const {};
    }

    try {
      final row = await _client
          .from('user_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) {
        return const {};
      }
      final loc = row['locale']?.toString() ?? 'en';
      return <String, dynamic>{
        'notificationsEnabled': row['notifications_enabled'] ?? true,
        'autoplayVideos': row['autoplay_videos'] ?? true,
        'locale': loc == 'ua' ? 'uk' : loc,
      };
    } catch (_) {
      return const {};
    }
  }

  Future<bool> isNotificationsEnabled() async {
    final settings = await getCurrentSettings();
    return settings['notificationsEnabled'] ?? true;
  }

  Future<bool> isAutoplayEnabled() async {
    final settings = await getCurrentSettings();
    return settings['autoplayVideos'] ?? true;
  }
}
