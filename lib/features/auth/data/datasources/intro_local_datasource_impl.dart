import 'package:shared_preferences/shared_preferences.dart';

import 'intro_local_datasource.dart';

class IntroLocalDataSourceImpl implements IntroLocalDataSource {
  static const _key = 'intro_video_completed_v1';

  @override
  Future<bool> getIntroCompleted() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setIntroCompleted(bool value) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, value);
    } catch (_) {}
  }
}
