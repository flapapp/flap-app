import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/app_auth.dart';
import 'core/config/supabase_env.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart' hide AuthState;
import 'router/app_router.dart';
import 'features/badges/domain/repositories/badges_repository.dart';
import 'features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/profile/data/services/user_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeSupabase();
  await configureDependencies();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('uk')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      saveLocale: true,
      child: const MyApp(),
    ),
  );
  unawaited(_bootstrapAppServices());
}

Future<void> _bootstrapAppServices() async {
  try {
    await NotificationService().initialize();
  } catch (e) {
    print('Failed to initialize NotificationService: $e');
  }

  try {
    await sl<BadgesRepository>().initializeDefaultBadges();
  } catch (e) {
    print('Failed to initialize badges: $e');
  }

  try {
    final uid = AppAuth.currentUserId;
    if (uid != null) {
      await sl<SubscriptionsRepository>().grantChampionsTrialIfMissing();
    } else {
      AppAuth.onAuthStateChange.listen((state) async {
        if (state.session?.user.id != null) {
          await sl<SubscriptionsRepository>().grantChampionsTrialIfMissing();
        }
      });
    }
  } catch (_) {}

  await _initMessaging();
}

Future<void> _initMessaging() async {
  // Push transport is intentionally disabled during Firebase removal.
  if (kIsWeb || SupabaseEnv.url.isEmpty || SupabaseEnv.anonKey.isEmpty) return;
  await UserSettingsService().isNotificationsEnabled();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSubscription;
  var _skipFirstAuthEvent = true;

  @override
  void initState() {
    super.initState();
    try {
      _authSubscription = AppAuth.onAuthStateChange.listen((state) {
        if (_skipFirstAuthEvent) {
          _skipFirstAuthEvent = false;
          return;
        }
        if (state.session != null) {
          return;
        }
        appRouter.replaceAll([const WelcomeRoute()]);
      });
    } catch (_) {}
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

    return BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(
        resolveStartup: sl(),
        signIn: sl(),
        registerNewUser: sl(),
        checkIntroCompleted: sl(),
        markIntroCompleted: sl(),
        postLoginActions: sl(),
      ),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'FLAP',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
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
