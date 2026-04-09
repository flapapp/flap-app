import 'package:auto_route/auto_route.dart';
import 'package:flap_app/features/admin/presentation/screens/admin_screen.dart';
import 'package:flap_app/features/auth/presentation/screens/login_screen.dart';
import 'package:flap_app/features/auth/presentation/screens/register_screen.dart';
import 'package:flap_app/features/challenges/presentation/screens/challenge_create_screen.dart';
import 'package:flap_app/features/challenges/presentation/screens/challenge_details_screen.dart';
import 'package:flap_app/features/challenges/presentation/screens/challenge_list_screen.dart';
import 'package:flap_app/features/friends/presentation/screens/friends_screen.dart';
import 'package:flap_app/features/matches/presentation/screens/create_match_screen.dart';
import 'package:flap_app/features/matches/presentation/screens/match_details_screen.dart';
import 'package:flap_app/features/matches/presentation/screens/match_management_screen.dart';
import 'package:flap_app/features/matches/presentation/screens/match_rating_screen.dart';
import 'package:flap_app/features/matches/presentation/screens/matches_screen.dart';
import 'package:flap_app/features/onboarding/presentation/screens/intro_video_screen.dart';
import 'package:flap_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:flap_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:flap_app/features/profile/presentation/screens/mode_selection_screen.dart';
import 'package:flap_app/features/profile/presentation/screens/player_profile_screen.dart';
import 'package:flap_app/features/profile/presentation/screens/profile_creation_screen.dart';
import 'package:flap_app/features/profile/presentation/screens/profile_screen_new.dart';
import 'package:flap_app/features/profile/presentation/screens/profile_settings_screen.dart';
import 'package:flap_app/features/profile/presentation/screens/stats_screen.dart';
import 'package:flap_app/features/teams/presentation/screens/team_details_screen.dart';
import 'package:flap_app/features/teams/presentation/screens/team_hub_screen.dart';
import 'package:flap_app/features/videos/presentation/screens/video_main_screen.dart';
import 'package:flap_app/features/videos/presentation/screens/video_upload_screen.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/models/match.dart';
import 'package:flap_app/features/matches/presentation/screens/ratings_screen.dart';
import 'package:flutter/material.dart';

import '../../utils/app_navigator.dart';
import 'auth_guards.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page|Screen,Route')
class AppRouter extends _$AppRouter {
  AppRouter({super.navigatorKey});

  final _authGuard = const AuthGuard();
  final _profileCompletionGuard = const ProfileCompletionGuard();
  final _guestOnlyGuard = const GuestOnlyGuard();
  final _firstLaunchGuard = const FirstLaunchGuard();

  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: IntroVideoRoute.page,
          initial: true,
          guards: [_firstLaunchGuard],
        ),
        AutoRoute(page: WelcomeRoute.page, guards: [_guestOnlyGuard]),
        AutoRoute(page: LoginRoute.page, guards: [_guestOnlyGuard]),
        AutoRoute(page: RegisterRoute.page, guards: [_guestOnlyGuard]),
        AutoRoute(page: AppProfileRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: ProfileSettingsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: ProfileCreationRoute.page, guards: [_authGuard]),
        AutoRoute(page: ModeSelectionRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: FriendsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: TeamHubRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: VideoUploadRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: VideoMainRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: ChallengeListRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: ChallengeCreateRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: ChallengeDetailsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: MatchesRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: RatingsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: MatchRatingRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: MatchDetailsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: MatchManagementRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: CreateMatchRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: PlayerProfileRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: NotificationsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: AdminRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: TeamDetailsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
        AutoRoute(page: StatsRoute.page, guards: [_authGuard, _profileCompletionGuard]),
      ];
}

/// Global root router — use [AppNavigator.navigatorKey] for navigation without [BuildContext].
final AppRouter appRouter = AppRouter(navigatorKey: AppNavigator.navigatorKey);
