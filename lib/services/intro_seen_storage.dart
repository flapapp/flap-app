import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the one-time intro ([IntroVideoRoute]) has been completed.
class IntroSeenStorage {
  static const _key = 'intro_video_completed_v1';

  static Future<bool> hasCompletedIntro() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markIntroCompleted() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, true);
    } catch (_) {}
  }
}
