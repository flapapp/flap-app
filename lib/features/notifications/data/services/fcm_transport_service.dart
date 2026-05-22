import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flap_app/firebase_options.dart';

typedef ForegroundMessageHandler = Future<void> Function(RemoteMessage message);
typedef NotificationTapHandler = Future<void> Function(Map<String, dynamic> data);
typedef TokenHandler = Future<void> Function(String token);

@pragma('vm:entry-point')
Future<void> notificationBackgroundMessageHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp();
    }
  }
}

class FcmTransportService {
  static const _channelId = 'flap_notifications';
  static const _channelName = 'Flap Notifications';

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _initialized = false;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(notificationBackgroundMessageHandler);
  }

  Future<void> initialize({
    required ForegroundMessageHandler onForegroundMessage,
    required NotificationTapHandler onNotificationTap,
    required TokenHandler onToken,
  }) async {
    if (kIsWeb || _initialized) return;
    if (Firebase.apps.isEmpty) return;
    _initialized = true;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _initializeLocalNotifications();

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await onNotificationTap(initialMessage.data);
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await onToken(token);
    }

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      if (token.isNotEmpty) await onToken(token);
    });

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
      await onForegroundMessage(message);
    });

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await onNotificationTap(message.data);
    });
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    await _tokenRefreshSub?.cancel();
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: darwinSettings),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Notifications from Flap',
            importance: Importance.high,
          ),
        );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.isEmpty ? null : message.data.toString(),
    );
  }
}
