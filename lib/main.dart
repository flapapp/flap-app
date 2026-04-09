import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/intro_video_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';
import 'screens/profile_creation_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/video_upload_screen.dart';
import 'screens/video_main_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_auth_context.dart';
import 'core/supabase_config.dart';
import 'features/auth/data/datasources/supabase_auth_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/data/datasources/supabase_profile_write_data_source.dart';
import 'features/auth/data/repositories/user_profile_repository_impl.dart';
import 'features/auth/domain/repositories/user_profile_repository.dart';
import 'screens/challenge_list_screen.dart';
import 'screens/challenge_create_screen.dart';
import 'screens/challenge_details_screen.dart';
import 'models/challenge.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/matches_screen.dart';
import 'screens/player_profile_screen.dart';
import 'models/match.dart' as app_models;
import 'screens/match_details_screen.dart';
import 'screens/create_match_screen.dart';
import 'screens/ratings_screen.dart';
import 'screens/match_rating_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/friends_screen.dart';
import 'services/subscription_service.dart';
import 'services/notification_service.dart';
import 'services/badge_service.dart';
import 'services/user_settings_service.dart';
import 'screens/match_management_screen.dart';
import 'utils/i18n.dart';
import 'utils/app_navigator.dart';
import 'screens/profile_screen_new.dart' as new_profile;
import 'screens/profile_settings_screen.dart';
import 'screens/team_hub_screen.dart';


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

class MyApp extends StatelessWidget {
  MyApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4caf50)),
      useMaterial3: true,
    );

    return BlocProvider(
      create: (context) => AuthBloc(
            authRepository,
            context.read<UserProfileRepository>(),
          )..add(const AuthStarted()),
      child: ValueListenableBuilder<String>(
      valueListenable: I18n.language,
      builder: (context, lang, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FLAP',
        navigatorKey: AppNavigator.navigatorKey,
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
        initialRoute: '/',
        routes: {
        '/': (context) => const IntroVideoScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/profile': (context) => new_profile.ProfileScreen(),
        '/settings': (context) => const ProfileSettingsScreen(),
        '/profile-creation': (context) => ProfileCreationScreen(),
        '/mode': (context) => ModeSelectionScreen(),
        '/friends': (context) => FriendsScreen(),
        '/teams': (context) => const TeamHubScreen(),
        '/video-upload': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return VideoUploadScreen(
                challengeId: args?['challengeId'],
                challengeTitle: args?['challengeTitle'],
              );
            },
        '/video-main': (context) => VideoMainScreen(),
        '/challenge-list': (context) => ChallengeListScreen(),
        '/challenge-create': (context) => ChallengeCreateScreen(),
        '/challenge-details': (context) {
          final challenge = ModalRoute.of(context)?.settings.arguments as Challenge;
          return ChallengeDetailsScreen(challenge: challenge);
        },
        '/matches': (context) => MatchesScreen(),
        '/ratings': (context) => RatingsScreen(),
                '/match_rating': (context) {
  final match = ModalRoute.of(context)?.settings.arguments as app_models.Match?;
  if (match == null) {
    return Scaffold(
      body: Center(child: Text(I18n.inline('Помилка: матч не знайдено', 'Error: match not found'))),
    );
  }
  return MatchRatingScreen(match: match);
},
        '/match-details': (context) {
        final app_models.Match match =
            ModalRoute.of(context)!.settings.arguments as app_models.Match;
        return MatchDetailsScreen(match: match);
      },
                '/match_management': (context) {
  final match = ModalRoute.of(context)!.settings.arguments as app_models.Match;
  return MatchManagementScreen(match: match, initialTabIndex: 1);
},
        '/create-match': (context) => CreateMatchScreen(),
        '/player-profile': (context) {
          final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
          return PlayerProfileScreen(
            playerId: args['playerId'] ?? args['userId'],
            playerName: args['playerName'] ?? '',
          );
        },
        '/notifications': (context) => NotificationsScreen(),
        '/admin': (context) => AdminScreen(),
        
        // VideoPlayerScreen не має маршруту, оскільки він викликається з параметрами
        },
      ),
    ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  Widget _buildLanguageButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
              )
            : null,
        color: selected ? null : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? Colors.white70 : Colors.white24,
          width: 1.4,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF4caf50).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1e7d32), Color(0xFF2e7d32)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип як у MVP
                  // Відображення лого з assets/logo/
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Image.asset(
                        'assets/logo/flap_logo.jpg',
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                // App name + language selector
                const Text(
                  'FLAP',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 8,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: I18n.language,
                  builder: (context, lang, _) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLanguageButton(
                        label: 'Українська',
                        selected: lang == 'uk',
                        onTap: () => I18n.setLanguage('uk'),
                      ),
                      const SizedBox(width: 12),
                      _buildLanguageButton(
                        label: 'English',
                        selected: lang == 'en',
                        onTap: () => I18n.setLanguage('en'),
                      ),
                    ],
                  ),
                ),
                  const SizedBox(height: 10),
                  // Підзаголовок
                ValueListenableBuilder<String>(
                  valueListenable: I18n.language,
                  builder: (context, lang, _) => Text(
                    'Feel Like A Pro\n${I18n.t('feel_like_a_pro')}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                )),
                  const SizedBox(height: 40),
                  // Кнопки як у MVP
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4caf50), Color(0xFF66bb6a)],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4caf50).withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            child: ValueListenableBuilder<String>(
                              valueListenable: I18n.language,
                              builder: (context, lang, _) => Text(
                                I18n.t('login'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            )),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: ValueListenableBuilder<String>(
                              valueListenable: I18n.language,
                              builder: (context, lang, _) => Text(
                                I18n.t('register'),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontSize: 16,
                              ),
                            )),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}  