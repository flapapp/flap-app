import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../features/challenges/data/models/challenge.dart';
import '../features/matches/data/models/match.dart';
import '../core/di/injection.dart';
import 'guards/auth_guard.dart';
import 'guards/avatar_required_guard.dart';
import 'guards/guest_guard.dart';
import '../features/admin/presentation/pages/admin_screen.dart';
import '../features/auth/presentation/pages/auth_bootstrap_page.dart';
import '../features/badges/presentation/pages/badges_store_screen.dart';
import '../features/challenges/presentation/pages/challenge_create_screen.dart';
import '../features/challenges/presentation/pages/challenge_details_screen.dart';
import '../features/challenges/presentation/pages/challenge_list_screen.dart';
import '../features/challenges/presentation/pages/challenge_video_player_screen.dart';
import '../features/matches/presentation/pages/create_match_screen.dart';
import '../features/friends/presentation/pages/friends_screen.dart';
import '../features/auth/presentation/pages/intro_video_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/matches/presentation/pages/match_details_screen.dart';
import '../features/matches/presentation/pages/match_management_screen.dart';
import '../features/ratings/presentation/pages/match_rating_screen.dart';
import '../features/matches/presentation/pages/matches_screen.dart';
import '../features/mode_selection/presentation/pages/mode_selection_screen.dart';
import '../features/notifications/presentation/pages/notifications_screen.dart';
import '../features/profile/presentation/pages/player_profile_page.dart';
import '../features/profile/presentation/pages/profile_creation_page.dart';
import '../features/profile/presentation/pages/profile_screen.dart';
import '../features/profile/presentation/pages/profile_settings_page.dart';
import '../features/ratings/presentation/pages/ratings_screen.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/avatar_required_page.dart';
import '../features/stats/presentation/pages/stats_screen.dart';
import '../features/subscriptions/presentation/pages/subscription_screen.dart';
import '../features/teams/presentation/pages/team_create_screen.dart';
import '../features/teams/presentation/pages/team_details_screen.dart';
import '../features/teams/presentation/pages/team_hub_screen.dart';
import '../features/video/presentation/pages/video_main_screen.dart';
import '../features/video/presentation/pages/video_player_screen.dart';
import '../features/video/presentation/pages/video_upload_screen.dart';
import '../features/video/presentation/pages/videos_screen.dart';
import '../screens/welcome_screen.dart';
import '../app_navigator_key.dart';

part 'app_router.gr.dart';

/// Lazy guards so [sl] is resolved after [configureDependencies] (not at import time).
AuthGuard get appAuthGuard => AuthGuard(sl());
AvatarRequiredGuard get appAvatarGuard => AvatarRequiredGuard(sl(), sl());
GuestGuard get appGuestGuard => GuestGuard(sl());

/// Global router instance for imperative navigation (e.g. push from services).
final AppRouter appRouter = AppRouter(navigatorKey: appNavigatorKey);

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  AppRouter({super.navigatorKey});

  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    AutoRoute(path: '/', page: AuthBootstrapRoute.page, initial: true),
    ..._guestRoutes,
    ..._authOnlyRoutes,
    ..._authAndAvatarRoutes,
  ];

  List<AutoRoute> get _guestRoutes => [
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
    AutoRoute(path: '/login', page: LoginRoute.page, guards: [appGuestGuard]),
    AutoRoute(
      path: '/register',
      page: RegisterRoute.page,
      guards: [appGuestGuard],
    ),
  ];

  List<AutoRoute> get _authOnlyRoutes => [
    AutoRoute(
      path: '/avatar-required',
      page: AvatarRequiredRoute.page,
      guards: [appAuthGuard],
    ),
  ];

  List<AutoRoute> get _authAndAvatarRoutes => [
    AutoRoute(
      path: '/profile',
      page: ProfileRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/settings',
      page: ProfileSettingsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/profile-creation',
      page: ProfileCreationRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
        AutoRoute(
          path: '/profile-stats',
          page: ProfileStatsRoute.page,
          guards: [appAuthGuard, appAvatarGuard],
        ),
    AutoRoute(
      path: '/mode',
      page: ModeSelectionRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/friends',
      page: FriendsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/teams',
      page: TeamHubRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/video-upload',
      page: VideoUploadRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/video-main',
      page: VideoMainRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/challenge-list',
      page: ChallengeListRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/challenge-create',
      page: ChallengeCreateRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/challenge-details',
      page: ChallengeDetailsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/matches',
      page: MatchesRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/ratings',
      page: RatingsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/match_rating',
      page: MatchRatingRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/match-details',
      page: MatchDetailsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/match_management',
      page: MatchManagementRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/create-match',
      page: CreateMatchRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/player-profile',
      page: PlayerProfileRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/notifications',
      page: NotificationsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/admin',
      page: AdminRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/team-details',
      page: TeamDetailsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/stats',
      page: StatsRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/subscription',
      page: SubscriptionRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/badges-store',
      page: BadgesStoreRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/video-player',
      page: VideoPlayerRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/challenge-video-player',
      page: ChallengeVideoPlayerRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/videos',
      page: VideosRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
    AutoRoute(
      path: '/team-create',
      page: TeamCreateRoute.page,
      guards: [appAuthGuard, appAvatarGuard],
    ),
  ];
}
