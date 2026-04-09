import 'package:auto_route/auto_route.dart';
import 'package:flap_app/features/auth/presentation/screens/login_screen.dart';
import 'package:flap_app/features/auth/presentation/screens/register_screen.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/screens/admin_screen.dart';
import 'package:flap_app/screens/challenge_create_screen.dart';
import 'package:flap_app/screens/challenge_details_screen.dart';
import 'package:flap_app/screens/challenge_list_screen.dart';
import 'package:flap_app/screens/create_match_screen.dart';
import 'package:flap_app/screens/friends_screen.dart';
import 'package:flap_app/screens/intro_video_screen.dart';
import 'package:flap_app/screens/match_details_screen.dart';
import 'package:flap_app/screens/match_management_screen.dart';
import 'package:flap_app/screens/match_rating_screen.dart';
import 'package:flap_app/screens/matches_screen.dart';
import 'package:flap_app/screens/mode_selection_screen.dart';
import 'package:flap_app/screens/notifications_screen.dart';
import 'package:flap_app/screens/player_profile_screen.dart';
import 'package:flap_app/screens/profile_creation_screen.dart';
import 'package:flap_app/screens/profile_screen_new.dart';
import 'package:flap_app/screens/profile_settings_screen.dart';
import 'package:flap_app/screens/ratings_screen.dart';
import 'package:flap_app/screens/stats_screen.dart';
import 'package:flap_app/screens/team_details_screen.dart';
import 'package:flap_app/screens/team_hub_screen.dart';
import 'package:flap_app/screens/video_main_screen.dart';
import 'package:flap_app/screens/video_upload_screen.dart';
import 'package:flap_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';

import '../../utils/app_navigator.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
class AppRouter extends _$AppRouter {
  AppRouter({super.navigatorKey});

  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: IntroVideoRoute.page, initial: true),
        AutoRoute(page: WelcomeRoute.page),
        AutoRoute(page: LoginRoute.page),
        AutoRoute(page: RegisterRoute.page),
        AutoRoute(page: AppProfileRoute.page),
        AutoRoute(page: ProfileSettingsRoute.page),
        AutoRoute(page: ProfileCreationRoute.page),
        AutoRoute(page: ModeSelectionRoute.page),
        AutoRoute(page: FriendsRoute.page),
        AutoRoute(page: TeamHubRoute.page),
        AutoRoute(page: VideoUploadRoute.page),
        AutoRoute(page: VideoMainRoute.page),
        AutoRoute(page: ChallengeListRoute.page),
        AutoRoute(page: ChallengeCreateRoute.page),
        AutoRoute(page: ChallengeDetailsRoute.page),
        AutoRoute(page: MatchesRoute.page),
        AutoRoute(page: RatingsRoute.page),
        AutoRoute(page: MatchRatingRoute.page),
        AutoRoute(page: MatchDetailsRoute.page),
        AutoRoute(page: MatchManagementRoute.page),
        AutoRoute(page: CreateMatchRoute.page),
        AutoRoute(page: PlayerProfileRoute.page),
        AutoRoute(page: NotificationsRoute.page),
        AutoRoute(page: AdminRoute.page),
        AutoRoute(page: TeamDetailsRoute.page),
        AutoRoute(page: StatsRoute.page),
      ];
}

/// Global root router — use [AppNavigator.navigatorKey] for navigation without [BuildContext].
final AppRouter appRouter = AppRouter(navigatorKey: AppNavigator.navigatorKey);
