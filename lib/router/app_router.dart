import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../models/match.dart';
import '../core/di/injection.dart';
import 'guards/auth_guard.dart';
import 'guards/guest_guard.dart';
import '../screens/admin_screen.dart';
import '../features/auth/presentation/pages/auth_bootstrap_page.dart';
import '../screens/badges_store_screen.dart';
import '../screens/challenge_completion_screen.dart';
import '../screens/challenge_create_screen.dart';
import '../screens/challenge_details_screen.dart';
import '../screens/challenge_list_screen.dart';
import '../screens/challenge_video_player_screen.dart';
import '../screens/create_match_screen.dart';
import '../screens/friends_screen.dart';
import '../features/auth/presentation/pages/intro_video_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../screens/match_details_screen.dart';
import '../screens/match_management_screen.dart';
import '../screens/match_rating_screen.dart';
import '../screens/matches_screen.dart';
import '../screens/mode_selection_screen.dart';
import '../screens/notifications_screen.dart';
import '../features/profile/presentation/pages/player_profile_page.dart';
import '../features/profile/presentation/pages/profile_creation_page.dart';
import '../features/profile/presentation/pages/profile_screen.dart';
import '../features/profile/presentation/pages/profile_settings_page.dart';
import '../screens/ratings_screen.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../screens/stats_screen.dart';
import '../screens/subscription_screen.dart';
import '../screens/team_create_screen.dart';
import '../screens/team_details_screen.dart';
import '../screens/team_hub_screen.dart';
import '../screens/video_main_screen.dart';
import '../screens/video_player_screen.dart';
import '../screens/video_upload_screen.dart';
import '../screens/videos_screen.dart';
import '../screens/welcome_screen.dart';

part 'app_router.gr.dart';

/// Lazy guards so [sl] is resolved after [configureDependencies] (not at import time).
AuthGuard get appAuthGuard => AuthGuard(sl());
GuestGuard get appGuestGuard => GuestGuard(sl());

/// Global router instance for imperative navigation (e.g. push from services).
final AppRouter appRouter = AppRouter();

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  AppRouter({GlobalKey<NavigatorState>? navigatorKey})
      : super(navigatorKey: navigatorKey);

  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
        AutoRoute(path: '/', page: AuthBootstrapRoute.page, initial: true),
        AutoRoute(
          path: '/intro',
          page: IntroVideoRoute.page,
          guards: [appGuestGuard],
        ),
        AutoRoute(
          path: '/welcome',
          page: WelcomeRoute.page,
          guards: [appGuestGuard],
        ),
        AutoRoute(
          path: '/login',
          page: LoginRoute.page,
          guards: [appGuestGuard],
        ),
        AutoRoute(
          path: '/register',
          page: RegisterRoute.page,
          guards: [appGuestGuard],
        ),
        AutoRoute(
          path: '/profile',
          page: ProfileRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/settings',
          page: ProfileSettingsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/profile-creation',
          page: ProfileCreationRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/mode',
          page: ModeSelectionRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/friends',
          page: FriendsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/teams',
          page: TeamHubRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/video-upload',
          page: VideoUploadRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/video-main',
          page: VideoMainRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/challenge-list',
          page: ChallengeListRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/challenge-create',
          page: ChallengeCreateRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/challenge-details',
          page: ChallengeDetailsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/matches',
          page: MatchesRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/ratings',
          page: RatingsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/match_rating',
          page: MatchRatingRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/match-details',
          page: MatchDetailsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/match_management',
          page: MatchManagementRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/create-match',
          page: CreateMatchRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/player-profile',
          page: PlayerProfileRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/notifications',
          page: NotificationsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/admin',
          page: AdminRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/team-details',
          page: TeamDetailsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/stats',
          page: StatsRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/subscription',
          page: SubscriptionRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/badges-store',
          page: BadgesStoreRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/video-player',
          page: VideoPlayerRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/challenge-video-player',
          page: ChallengeVideoPlayerRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/videos',
          page: VideosRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/team-create',
          page: TeamCreateRoute.page,
          guards: [appAuthGuard],
        ),
        AutoRoute(
          path: '/challenge-completion',
          page: ChallengeCompletionRoute.page,
          guards: [appAuthGuard],
        ),
      ];
}
