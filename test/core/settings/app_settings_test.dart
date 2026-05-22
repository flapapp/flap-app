import 'package:flap_app/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings.fromRemoteRow', () {
    test('maps ua locale and boolean columns', () {
      final settings = AppSettings.fromRemoteRow(<String, dynamic>{
        'locale': 'ua',
        'notifications_enabled': false,
        'autoplay_videos': false,
        'show_online_status': false,
        'allow_friend_requests': false,
      });

      expect(settings.locale, 'uk');
      expect(settings.notificationsEnabled, isFalse);
      expect(settings.autoplayVideos, isFalse);
      expect(settings.showOnlineStatus, isFalse);
      expect(settings.allowFriendRequests, isFalse);
    });

    test('defaults when row is null', () {
      expect(AppSettings.fromRemoteRow(null), AppSettings.defaults);
    });
  });

  group('AppSettings.toSettingsPatch', () {
    test('includes all keys for merge', () {
      const settings = AppSettings(locale: 'uk', notificationsEnabled: false);
      final patch = settings.toSettingsPatch();
      expect(patch['locale'], 'uk');
      expect(patch['notificationsEnabled'], isFalse);
      expect(patch.containsKey('showOnlineStatus'), isTrue);
    });
  });
}
