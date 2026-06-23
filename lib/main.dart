import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/app_auth.dart';
import 'theme/flap_tokens.dart';
import 'core/config/supabase_env.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/di/injection.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart' hide AuthState;
import 'router/app_router.dart';
import 'features/badges/domain/repositories/badges_repository.dart';
import 'features/subscriptions/domain/repositories/subscriptions_repository.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'core/settings/app_settings_cubit.dart';
import 'features/profile/data/services/user_settings_service.dart';
import 'features/notifications/data/services/fcm_transport_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FcmTransportService.registerBackgroundHandler();
  await EasyLocalization.ensureInitialized();
  await _initializeFirebase();
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

Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) return;
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    print('Firebase initialization failed: $e');
  }
}

Future<void> _bootstrapAppServices() async {
  try {
    await sl<NotificationService>().initialize();
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
  if (kIsWeb || SupabaseEnv.url.isEmpty || SupabaseEnv.anonKey.isEmpty) return;
  if (Firebase.apps.isEmpty) return;
  if (AppAuth.currentUserId != null) {
    await sl<AppSettingsCubit>().load(forceRefresh: true);
  }
  if (!sl<UserSettingsService>().notificationsEnabled) return;
  await sl<NotificationService>().syncCurrentUserToken();
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
    if (AppAuth.currentUserId != null) {
      unawaited(sl<AppSettingsCubit>().load(forceRefresh: true));
    }
    try {
      _authSubscription = AppAuth.onAuthStateChange.listen((state) {
        if (_skipFirstAuthEvent) {
          _skipFirstAuthEvent = false;
          if (state.session != null) {
            unawaited(sl<AppSettingsCubit>().load(forceRefresh: true));
          }
          return;
        }
        if (state.session != null) {
          unawaited(sl<AppSettingsCubit>().load(forceRefresh: true));
          return;
        }
        sl<AppSettingsCubit>().reset();
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
    final flapTheme = buildFlapTheme();

    return BlocProvider.value(
      value: sl<AppSettingsCubit>(),
      child: BlocProvider<AuthBloc>(
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
        title: 'Flap',
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        theme: flapTheme,
        // AutoRouteObserver drives RouteAware callbacks (didPushNext /
        // didPopNext) so video screens can pause when covered and resume on
        // return.
        routerConfig: appRouter.config(
          navigatorObservers: () => [AutoRouteObserver()],
        ),
        ),
      ),
    );
  }
}
