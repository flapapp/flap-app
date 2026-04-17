import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../models/match.dart';
import '../screens/admin_screen.dart';
import '../screens/badges_store_screen.dart';
import '../screens/challenge_completion_screen.dart';
import '../screens/challenge_create_screen.dart';
import '../screens/challenge_details_screen.dart';
import '../screens/challenge_list_screen.dart';
import '../screens/challenge_video_player_screen.dart';
import '../screens/create_match_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/intro_video_screen.dart';
import '../screens/login_screen.dart';
import '../screens/match_details_screen.dart';
import '../screens/match_management_screen.dart';
import '../screens/match_rating_screen.dart';
import '../screens/matches_screen.dart';
import '../screens/mode_selection_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/player_profile_screen.dart';
import '../screens/profile_creation_screen.dart';
import '../screens/profile_screen_new.dart';
import '../screens/profile_settings_screen.dart';
import '../screens/ratings_screen.dart';
import '../screens/register_screen.dart';
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
        AutoRoute(path: '/', page: IntroVideoRoute.page, initial: true),
        AutoRoute(path: '/welcome', page: WelcomeRoute.page),
        AutoRoute(path: '/login', page: LoginRoute.page),
        AutoRoute(path: '/register', page: RegisterRoute.page),
        AutoRoute(path: '/profile', page: ProfileRoute.page),
        AutoRoute(path: '/settings', page: ProfileSettingsRoute.page),
        AutoRoute(path: '/profile-creation', page: ProfileCreationRoute.page),
        AutoRoute(path: '/mode', page: ModeSelectionRoute.page),
        AutoRoute(path: '/friends', page: FriendsRoute.page),
        AutoRoute(path: '/teams', page: TeamHubRoute.page),
        AutoRoute(path: '/video-upload', page: VideoUploadRoute.page),
        AutoRoute(path: '/video-main', page: VideoMainRoute.page),
        AutoRoute(path: '/challenge-list', page: ChallengeListRoute.page),
        AutoRoute(path: '/challenge-create', page: ChallengeCreateRoute.page),
        AutoRoute(path: '/challenge-details', page: ChallengeDetailsRoute.page),
        AutoRoute(path: '/matches', page: MatchesRoute.page),
        AutoRoute(path: '/ratings', page: RatingsRoute.page),
        AutoRoute(path: '/match_rating', page: MatchRatingRoute.page),
        AutoRoute(path: '/match-details', page: MatchDetailsRoute.page),
        AutoRoute(path: '/match_management', page: MatchManagementRoute.page),
        AutoRoute(path: '/create-match', page: CreateMatchRoute.page),
        AutoRoute(path: '/player-profile', page: PlayerProfileRoute.page),
        AutoRoute(path: '/notifications', page: NotificationsRoute.page),
        AutoRoute(path: '/admin', page: AdminRoute.page),
        AutoRoute(path: '/team-details', page: TeamDetailsRoute.page),
        AutoRoute(path: '/stats', page: StatsRoute.page),
        AutoRoute(path: '/subscription', page: SubscriptionRoute.page),
        AutoRoute(path: '/badges-store', page: BadgesStoreRoute.page),
        AutoRoute(path: '/video-player', page: VideoPlayerRoute.page),
        AutoRoute(path: '/challenge-video-player', page: ChallengeVideoPlayerRoute.page),
        AutoRoute(path: '/videos', page: VideosRoute.page),
        AutoRoute(path: '/team-create', page: TeamCreateRoute.page),
        AutoRoute(path: '/challenge-completion', page: ChallengeCompletionRoute.page),
      ];
}
