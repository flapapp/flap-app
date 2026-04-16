import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/flap_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'core/app_auth_context.dart';
import 'core/app_user_profile_context.dart';
import 'core/navigation/flap_route_observer.dart';
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
import 'features/matches/data/rating_service.dart';
import 'features/videos/data/datasources/supabase_videos_remote_data_source.dart';
import 'features/videos/data/repositories/videos_repository_impl.dart';
import 'features/videos/domain/repositories/videos_repository.dart';
import 'features/admin/data/datasources/supabase_admin_remote_data_source.dart';
import 'features/admin/data/repositories/admin_repository_impl.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/badges/data/datasources/supabase_badge_remote_data_source.dart';
import 'features/badges/data/repositories/badge_repository_impl.dart';
import 'features/badges/domain/repositories/badge_repository.dart';
import 'features/challenges/data/datasources/supabase_challenge_remote_data_source.dart';
import 'features/challenges/data/repositories/challenge_repository_impl.dart';
import 'features/challenges/domain/repositories/challenge_repository.dart';
import 'features/friends/data/datasources/supabase_friends_remote_data_source.dart';
import 'features/friends/data/repositories/friends_repository_impl.dart';
import 'features/friends/domain/repositories/friends_repository.dart';
import 'features/matches/data/datasources/supabase_matches_remote_data_source.dart';
import 'features/matches/data/match_service.dart';
import 'features/matches/domain/repositories/matches_repository.dart';
import 'features/teams/team_creation/data/datasources/team_creation_remote_data_source.dart';
import 'features/teams/team_creation/data/repositories/team_creation_repository_impl.dart';
import 'features/teams/team_creation/domain/repositories/team_creation_repository.dart';
import 'features/teams/data/datasources/supabase_teams_remote_data_source.dart';
import 'features/teams/data/repositories/teams_repository_impl.dart';
import 'features/teams/domain/repositories/teams_repository.dart';
import 'features/teams/presentation/bloc/teams_bloc.dart';
import 'features/notifications/data/datasources/supabase_notifications_remote_data_source.dart';
import 'features/notifications/data/notification_service.dart';
import 'features/notifications/data/repositories/notifications_repository_impl.dart';
import 'features/notifications/domain/repositories/notifications_repository.dart';
import 'package:flap_app/features/profile/data/datasources/supabase_profile_remote_data_source.dart';
import 'package:flap_app/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flap_app/features/profile/data/user_settings_service.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/features/subscription/data/datasources/supabase_subscription_remote_data_source.dart';
import 'package:flap_app/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:flap_app/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:flap_app/features/tournaments/data/datasources/supabase_tournaments_remote_data_source.dart';
import 'package:flap_app/features/tournaments/data/repositories/tournaments_repository_impl.dart';
import 'package:flap_app/features/tournaments/domain/repositories/tournaments_repository.dart';
import 'package:flap_app/features/wallet/data/datasources/supabase_wallet_remote_data_source.dart';
import 'package:flap_app/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:flap_app/features/wallet/domain/repositories/wallet_repository.dart';
import 'utils/i18n.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  AppUserProfileContext.repository = userProfileRepo;

  final adminRepo = AdminRepositoryImpl(SupabaseAdminRemoteDataSource());
  final badgeRepo = BadgeRepositoryImpl(SupabaseBadgeRemoteDataSource());
  final challengeRepo =
      ChallengeRepositoryImpl(SupabaseChallengeRemoteDataSource());
  final friendsRepo = FriendsRepositoryImpl(
    SupabaseFriendsRemoteDataSource(),
    userProfileRepo,
  );
  MatchesRepository? matchesRepoRef;
  final teamsRepo = TeamsRepositoryImpl(
    SupabaseTeamsRemoteDataSource(),
    () => matchesRepoRef!,
  );
  final matchesRepo = MatchesRepositoryImpl(
    SupabaseMatchesRemoteDataSource(),
    userProfileRepo,
    teamsRepo,
  );
  matchesRepoRef = matchesRepo;
  final notificationsRepo = NotificationsRepositoryImpl(
    SupabaseNotificationsRemoteDataSource(),
  );
  NotificationService.matchesRepository = matchesRepo;

  final profileRepo = ProfileRepositoryImpl(
    remote: SupabaseProfileRemoteDataSource(),
  );
  UserSettingsService.registerGlobalRepository(profileRepo);

  final subscriptionRepo = SubscriptionRepositoryImpl(
    remote: SupabaseSubscriptionRemoteDataSource(),
  );

  final videosRepo = VideosRepositoryImpl(SupabaseVideosRemoteDataSource());
  RatingService.registerVideosRepository(videosRepo);

  final teamCreationRepo = TeamCreationRepositoryImpl(
    SupabaseTeamCreationRemoteDataSource(),
  );
  final walletRepo = WalletRepositoryImpl(SupabaseWalletRemoteDataSource());
  final tournamentsRepo =
      TournamentsRepositoryImpl(SupabaseTournamentsRemoteDataSource());

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepo),
        RepositoryProvider<UserProfileRepository>.value(
          value: userProfileRepo,
        ),
        RepositoryProvider<ProfileRepository>.value(value: profileRepo),
        RepositoryProvider<SubscriptionRepository>.value(
          value: subscriptionRepo,
        ),
        RepositoryProvider<AdminRepository>.value(value: adminRepo),
        RepositoryProvider<BadgeRepository>.value(value: badgeRepo),
        RepositoryProvider<ChallengeRepository>.value(value: challengeRepo),
        RepositoryProvider<FriendsRepository>.value(value: friendsRepo),
        RepositoryProvider<TeamsRepository>.value(value: teamsRepo),
        RepositoryProvider<MatchesRepository>.value(value: matchesRepo),
        RepositoryProvider<NotificationsRepository>.value(
          value: notificationsRepo,
        ),
        RepositoryProvider<VideosRepository>.value(value: videosRepo),
        RepositoryProvider<TeamCreationRepository>.value(
          value: teamCreationRepo,
        ),
        RepositoryProvider<WalletRepository>.value(value: walletRepo),
        RepositoryProvider<TournamentsRepository>.value(value: tournamentsRepo),
      ],
      child: MyApp(authRepository: authRepo),
    ),
  );
  unawaited(_bootstrapAppServices(badgeRepo, subscriptionRepo));
}

Future<void> _bootstrapAppServices(
  BadgeRepository badgeRepo,
  SubscriptionRepository subscriptionRepo,
) async {
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
    await badgeRepo.initializeDefaultBadges();
  } catch (e) {
    print('Failed to initialize badges: $e');
  }

  // Grant Champions trial silently (per user)
  try {
    final repo = AppAuthContext.repository;
    if (repo != null) {
      final initial = repo.currentUser;
      if (initial != null) {
        await subscriptionRepo.grantChampionsTrialIfMissing();
      }
      repo.authStateChanges.listen((u) async {
        if (u != null) {
          await subscriptionRepo.grantChampionsTrialIfMissing();
        }
      });
    }
  } catch (_) {}
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(
                widget.authRepository,
                context.read<UserProfileRepository>(),
              )..add(const AuthStarted()),
        ),
        BlocProvider(
          create: (context) => TeamsBloc(context.read<TeamsRepository>()),
        ),
      ],
      child: ValueListenableBuilder<String>(
      valueListenable: I18n.language,
      builder: (context, lang, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'FLAP',
        theme: FlapTheme.theme(),
        routerConfig: appRouter.config(
          reevaluateListenable: _authReevaluateListenable,
          navigatorObservers: () => [flapRouteObserver],
        ),
      ),
    ),
  );
  }
}