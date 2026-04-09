import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'core/app_auth_context.dart';
import 'core/router/app_router.dart';
import 'core/supabase_config.dart';
import 'features/auth/data/datasources/supabase_auth_data_source.dart';
import 'features/auth/data/datasources/supabase_profile_write_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/user_profile_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/repositories/user_profile_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'firebase_options.dart';
import 'services/badge_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/user_settings_service.dart';
import 'utils/i18n.dart';


@pragma('vm:entry-point')
Future<void> _pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SupabaseConfig.assertConfigured();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final authRepo = AuthRepositoryImpl(SupabaseAuthDataSource());
  AppAuthContext.repository = authRepo;

  final userProfileRepo = UserProfileRepositoryImpl(
    supabase: SupabaseProfileWriteDataSource(),
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepo),
        RepositoryProvider<UserProfileRepository>.value(
          value: userProfileRepo,
        ),
      ],
      child: MyApp(authRepository: authRepo),
    ),
  );
  unawaited(_bootstrapAppServices());
}

Future<void> _bootstrapAppServices() async {
  if (kIsWeb) {
    try {
      await AppAuthContext.repository?.setWebPersistenceLocal();
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
    final repo = AppAuthContext.repository;
    if (repo != null) {
      final initial = repo.currentUser;
      if (initial != null) {
        await SubscriptionService().grantChampionsTrialIfMissing();
      }
      repo.authStateChanges.listen((u) async {
        if (u != null) {
          await SubscriptionService().grantChampionsTrialIfMissing();
        }
      });
    }
  } catch (_) {}

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_pushBackgroundHandler);
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
  final userId = AppAuthContext.userId;
  if (userId != null && token != null) {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await userRef.set({
      'deviceTokens': FieldValue.arrayUnion([token])
    }, SetOptions(merge: true));
  }

  FirebaseMessaging.onMessage.listen((message) {
    // Optionally show in-app notification UI
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ReevaluateListenable _authReevaluateListenable;

  @override
  void initState() {
    super.initState();
    _authReevaluateListenable =
        ReevaluateListenable.stream(widget.authRepository.authStateChanges);
  }

  @override
  void dispose() {
    _authReevaluateListenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4caf50)),
      useMaterial3: true,
    );

    return BlocProvider(
      create: (context) => AuthBloc(
            widget.authRepository,
            context.read<UserProfileRepository>(),
          )..add(const AuthStarted()),
      child: ValueListenableBuilder<String>(
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
        routerConfig: appRouter.config(
          reevaluateListenable: _authReevaluateListenable,
        ),
      ),
    ),
    );
  }
}