import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/badge_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/user_settings_service.dart';
import 'utils/i18n.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
  unawaited(_bootstrapAppServices());
}

Future<void> _bootstrapAppServices() async {
  // Keep user logged in between browser sessions.
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {}
  }

  // Initialize NotificationService
  try {
    await NotificationService().initialize();
  } catch (e) {
    print('Failed to initialize NotificationService: $e');
  }

  // Initialize default badges
  try {
    await BadgeService().initializeDefaultBadges();
  } catch (e) {
    print('Failed to initialize badges: $e');
  }

  // Grant Champions trial silently (per user)
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await SubscriptionService().grantChampionsTrialIfMissing();
    } else {
      FirebaseAuth.instance.authStateChanges().listen((u) async {
        if (u != null) {
          await SubscriptionService().grantChampionsTrialIfMissing();
        }
      });
    }
  } catch (_) {}

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initMessaging();
  }
}

Future<void> _initMessaging() async {
  if (!await UserSettingsService().isNotificationsEnabled()) {
    return;
  }
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  final token = await messaging.getToken();
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && token != null) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set({
      'deviceTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  FirebaseMessaging.onMessage.listen((message) {
    // Optionally show in-app notification UI
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Initial route is handled by [AuthBootstrapScreen]; skip the first emission
    // so we only react to sign-out (or session loss) after startup.
    try {
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().skip(1).listen((user) {
        if (user != null) return;
        appRouter.replaceAll([const WelcomeRoute()]);
      });
    } catch (_) {
      // Tests or environments without Firebase — routing still works via guards.
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4caf50)),
      useMaterial3: true,
    );

    return ValueListenableBuilder<String>(
      valueListenable: I18n.language,
      builder: (context, lang, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'FLAP',
        theme: baseTheme.copyWith(
          textTheme: GoogleFonts.robotoTextTheme(baseTheme.textTheme),
          appBarTheme: baseTheme.appBarTheme.copyWith(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            foregroundColor: Colors.white,
          ),
        ),
        routerConfig: appRouter.config(),
      ),
    );
  }
}