// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

abstract class _$AppRouter extends RootStackRouter {
  // ignore: unused_element
  _$AppRouter({super.navigatorKey});

  @override
  final Map<String, PageFactory> pagesMap = {
    AdminRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: AdminScreen(),
      );
    },
    ChallengeCreateRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ChallengeCreateScreen(),
      );
    },
    ChallengeDetailsRoute.name: (routeData) {
      final args = routeData.argsAs<ChallengeDetailsRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ChallengeDetailsScreen(
          key: args.key,
          challenge: args.challenge,
        ),
      );
    },
    ChallengeListRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ChallengeListScreen(),
      );
    },
    CreateMatchRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const CreateMatchScreen(),
      );
    },
    FriendsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: FriendsScreen(),
      );
    },
    IntroVideoRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const IntroVideoScreen(),
      );
    },
    LoginRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: LoginScreen(),
      );
    },
    MatchDetailsRoute.name: (routeData) {
      final args = routeData.argsAs<MatchDetailsRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: MatchDetailsScreen(
          key: args.key,
          match: args.match,
        ),
      );
    },
    MatchManagementRoute.name: (routeData) {
      final args = routeData.argsAs<MatchManagementRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: MatchManagementScreen(
          key: args.key,
          match: args.match,
          initialTabIndex: args.initialTabIndex,
        ),
      );
    },
    MatchRatingRoute.name: (routeData) {
      final args = routeData.argsAs<MatchRatingRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: MatchRatingScreen(
          key: args.key,
          match: args.match,
        ),
      );
    },
    MatchesRoute.name: (routeData) {
      final args = routeData.argsAs<MatchesRouteArgs>(
          orElse: () => const MatchesRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: MatchesScreen(
          key: args.key,
          initialTabIndex: args.initialTabIndex,
        ),
      );
    },
    ModeSelectionRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const ModeSelectionScreen(),
      );
    },
    NotificationsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: NotificationsScreen(),
      );
    },
    PlayerProfileRoute.name: (routeData) {
      final args = routeData.argsAs<PlayerProfileRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: PlayerProfileScreen(
          key: args.key,
          playerId: args.playerId,
          playerName: args.playerName,
        ),
      );
    },
    ProfileCreationRoute.name: (routeData) {
      final args = routeData.argsAs<ProfileCreationRouteArgs>(
          orElse: () => const ProfileCreationRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ProfileCreationScreen(
          key: args.key,
          isEditing: args.isEditing,
        ),
      );
    },
    AppProfileRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: ProfileScreen(),
      );
    },
    ProfileSettingsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const ProfileSettingsScreen(),
      );
    },
    RatingsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: RatingsScreen(),
      );
    },
    RegisterRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: RegisterScreen(),
      );
    },
    StatsRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const StatsScreen(),
      );
    },
    TeamDetailsRoute.name: (routeData) {
      final args = routeData.argsAs<TeamDetailsRouteArgs>();
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: TeamDetailsScreen(
          key: args.key,
          teamId: args.teamId,
        ),
      );
    },
    TeamHubRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const TeamHubScreen(),
      );
    },
    VideoMainRoute.name: (routeData) {
      final args = routeData.argsAs<VideoMainRouteArgs>(
          orElse: () => const VideoMainRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: VideoMainScreen(
          key: args.key,
          myContent: args.myContent,
        ),
      );
    },
    VideoUploadRoute.name: (routeData) {
      final args = routeData.argsAs<VideoUploadRouteArgs>(
          orElse: () => const VideoUploadRouteArgs());
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: VideoUploadScreen(
          key: args.key,
          challengeId: args.challengeId,
          challengeTitle: args.challengeTitle,
        ),
      );
    },
    WelcomeRoute.name: (routeData) {
      return AutoRoutePage<dynamic>(
        routeData: routeData,
        child: const WelcomeScreen(),
      );
    },
  };
}

/// generated route for
/// [AdminScreen]
class AdminRoute extends PageRouteInfo<void> {
  const AdminRoute({List<PageRouteInfo>? children})
      : super(
          AdminRoute.name,
          initialChildren: children,
        );

  static const String name = 'AdminRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [ChallengeCreateScreen]
class ChallengeCreateRoute extends PageRouteInfo<void> {
  const ChallengeCreateRoute({List<PageRouteInfo>? children})
      : super(
          ChallengeCreateRoute.name,
          initialChildren: children,
        );

  static const String name = 'ChallengeCreateRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [ChallengeDetailsScreen]
class ChallengeDetailsRoute extends PageRouteInfo<ChallengeDetailsRouteArgs> {
  ChallengeDetailsRoute({
    Key? key,
    required Challenge challenge,
    List<PageRouteInfo>? children,
  }) : super(
          ChallengeDetailsRoute.name,
          args: ChallengeDetailsRouteArgs(
            key: key,
            challenge: challenge,
          ),
          initialChildren: children,
        );

  static const String name = 'ChallengeDetailsRoute';

  static const PageInfo<ChallengeDetailsRouteArgs> page =
      PageInfo<ChallengeDetailsRouteArgs>(name);
}

class ChallengeDetailsRouteArgs {
  const ChallengeDetailsRouteArgs({
    this.key,
    required this.challenge,
  });

  final Key? key;

  final Challenge challenge;

  @override
  String toString() {
    return 'ChallengeDetailsRouteArgs{key: $key, challenge: $challenge}';
  }
}

/// generated route for
/// [ChallengeListScreen]
class ChallengeListRoute extends PageRouteInfo<void> {
  const ChallengeListRoute({List<PageRouteInfo>? children})
      : super(
          ChallengeListRoute.name,
          initialChildren: children,
        );

  static const String name = 'ChallengeListRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [CreateMatchScreen]
class CreateMatchRoute extends PageRouteInfo<void> {
  const CreateMatchRoute({List<PageRouteInfo>? children})
      : super(
          CreateMatchRoute.name,
          initialChildren: children,
        );

  static const String name = 'CreateMatchRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [FriendsScreen]
class FriendsRoute extends PageRouteInfo<void> {
  const FriendsRoute({List<PageRouteInfo>? children})
      : super(
          FriendsRoute.name,
          initialChildren: children,
        );

  static const String name = 'FriendsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [IntroVideoScreen]
class IntroVideoRoute extends PageRouteInfo<void> {
  const IntroVideoRoute({List<PageRouteInfo>? children})
      : super(
          IntroVideoRoute.name,
          initialChildren: children,
        );

  static const String name = 'IntroVideoRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [LoginScreen]
class LoginRoute extends PageRouteInfo<void> {
  const LoginRoute({List<PageRouteInfo>? children})
      : super(
          LoginRoute.name,
          initialChildren: children,
        );

  static const String name = 'LoginRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [MatchDetailsScreen]
class MatchDetailsRoute extends PageRouteInfo<MatchDetailsRouteArgs> {
  MatchDetailsRoute({
    Key? key,
    required Match match,
    List<PageRouteInfo>? children,
  }) : super(
          MatchDetailsRoute.name,
          args: MatchDetailsRouteArgs(
            key: key,
            match: match,
          ),
          initialChildren: children,
        );

  static const String name = 'MatchDetailsRoute';

  static const PageInfo<MatchDetailsRouteArgs> page =
      PageInfo<MatchDetailsRouteArgs>(name);
}

class MatchDetailsRouteArgs {
  const MatchDetailsRouteArgs({
    this.key,
    required this.match,
  });

  final Key? key;

  final Match match;

  @override
  String toString() {
    return 'MatchDetailsRouteArgs{key: $key, match: $match}';
  }
}

/// generated route for
/// [MatchManagementScreen]
class MatchManagementRoute extends PageRouteInfo<MatchManagementRouteArgs> {
  MatchManagementRoute({
    Key? key,
    required Match match,
    int initialTabIndex = 1,
    List<PageRouteInfo>? children,
  }) : super(
          MatchManagementRoute.name,
          args: MatchManagementRouteArgs(
            key: key,
            match: match,
            initialTabIndex: initialTabIndex,
          ),
          initialChildren: children,
        );

  static const String name = 'MatchManagementRoute';

  static const PageInfo<MatchManagementRouteArgs> page =
      PageInfo<MatchManagementRouteArgs>(name);
}

class MatchManagementRouteArgs {
  const MatchManagementRouteArgs({
    this.key,
    required this.match,
    this.initialTabIndex = 1,
  });

  final Key? key;

  final Match match;

  final int initialTabIndex;

  @override
  String toString() {
    return 'MatchManagementRouteArgs{key: $key, match: $match, initialTabIndex: $initialTabIndex}';
  }
}

/// generated route for
/// [MatchRatingScreen]
class MatchRatingRoute extends PageRouteInfo<MatchRatingRouteArgs> {
  MatchRatingRoute({
    Key? key,
    required Match match,
    List<PageRouteInfo>? children,
  }) : super(
          MatchRatingRoute.name,
          args: MatchRatingRouteArgs(
            key: key,
            match: match,
          ),
          initialChildren: children,
        );

  static const String name = 'MatchRatingRoute';

  static const PageInfo<MatchRatingRouteArgs> page =
      PageInfo<MatchRatingRouteArgs>(name);
}

class MatchRatingRouteArgs {
  const MatchRatingRouteArgs({
    this.key,
    required this.match,
  });

  final Key? key;

  final Match match;

  @override
  String toString() {
    return 'MatchRatingRouteArgs{key: $key, match: $match}';
  }
}

/// generated route for
/// [MatchesScreen]
class MatchesRoute extends PageRouteInfo<MatchesRouteArgs> {
  MatchesRoute({
    Key? key,
    int? initialTabIndex,
    List<PageRouteInfo>? children,
  }) : super(
          MatchesRoute.name,
          args: MatchesRouteArgs(
            key: key,
            initialTabIndex: initialTabIndex,
          ),
          initialChildren: children,
        );

  static const String name = 'MatchesRoute';

  static const PageInfo<MatchesRouteArgs> page =
      PageInfo<MatchesRouteArgs>(name);
}

class MatchesRouteArgs {
  const MatchesRouteArgs({
    this.key,
    this.initialTabIndex,
  });

  final Key? key;

  final int? initialTabIndex;

  @override
  String toString() {
    return 'MatchesRouteArgs{key: $key, initialTabIndex: $initialTabIndex}';
  }
}

/// generated route for
/// [ModeSelectionScreen]
class ModeSelectionRoute extends PageRouteInfo<void> {
  const ModeSelectionRoute({List<PageRouteInfo>? children})
      : super(
          ModeSelectionRoute.name,
          initialChildren: children,
        );

  static const String name = 'ModeSelectionRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [NotificationsScreen]
class NotificationsRoute extends PageRouteInfo<void> {
  const NotificationsRoute({List<PageRouteInfo>? children})
      : super(
          NotificationsRoute.name,
          initialChildren: children,
        );

  static const String name = 'NotificationsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [PlayerProfileScreen]
class PlayerProfileRoute extends PageRouteInfo<PlayerProfileRouteArgs> {
  PlayerProfileRoute({
    Key? key,
    required String playerId,
    String? playerName,
    List<PageRouteInfo>? children,
  }) : super(
          PlayerProfileRoute.name,
          args: PlayerProfileRouteArgs(
            key: key,
            playerId: playerId,
            playerName: playerName,
          ),
          initialChildren: children,
        );

  static const String name = 'PlayerProfileRoute';

  static const PageInfo<PlayerProfileRouteArgs> page =
      PageInfo<PlayerProfileRouteArgs>(name);
}

class PlayerProfileRouteArgs {
  const PlayerProfileRouteArgs({
    this.key,
    required this.playerId,
    this.playerName,
  });

  final Key? key;

  final String playerId;

  final String? playerName;

  @override
  String toString() {
    return 'PlayerProfileRouteArgs{key: $key, playerId: $playerId, playerName: $playerName}';
  }
}

/// generated route for
/// [ProfileCreationScreen]
class ProfileCreationRoute extends PageRouteInfo<ProfileCreationRouteArgs> {
  ProfileCreationRoute({
    Key? key,
    bool isEditing = false,
    List<PageRouteInfo>? children,
  }) : super(
          ProfileCreationRoute.name,
          args: ProfileCreationRouteArgs(
            key: key,
            isEditing: isEditing,
          ),
          initialChildren: children,
        );

  static const String name = 'ProfileCreationRoute';

  static const PageInfo<ProfileCreationRouteArgs> page =
      PageInfo<ProfileCreationRouteArgs>(name);
}

class ProfileCreationRouteArgs {
  const ProfileCreationRouteArgs({
    this.key,
    this.isEditing = false,
  });

  final Key? key;

  final bool isEditing;

  @override
  String toString() {
    return 'ProfileCreationRouteArgs{key: $key, isEditing: $isEditing}';
  }
}

/// generated route for
/// [ProfileScreen]
class AppProfileRoute extends PageRouteInfo<void> {
  const AppProfileRoute({List<PageRouteInfo>? children})
      : super(
          AppProfileRoute.name,
          initialChildren: children,
        );

  static const String name = 'AppProfileRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [ProfileSettingsScreen]
class ProfileSettingsRoute extends PageRouteInfo<void> {
  const ProfileSettingsRoute({List<PageRouteInfo>? children})
      : super(
          ProfileSettingsRoute.name,
          initialChildren: children,
        );

  static const String name = 'ProfileSettingsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [RatingsScreen]
class RatingsRoute extends PageRouteInfo<void> {
  const RatingsRoute({List<PageRouteInfo>? children})
      : super(
          RatingsRoute.name,
          initialChildren: children,
        );

  static const String name = 'RatingsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [RegisterScreen]
class RegisterRoute extends PageRouteInfo<void> {
  const RegisterRoute({List<PageRouteInfo>? children})
      : super(
          RegisterRoute.name,
          initialChildren: children,
        );

  static const String name = 'RegisterRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [StatsScreen]
class StatsRoute extends PageRouteInfo<void> {
  const StatsRoute({List<PageRouteInfo>? children})
      : super(
          StatsRoute.name,
          initialChildren: children,
        );

  static const String name = 'StatsRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [TeamDetailsScreen]
class TeamDetailsRoute extends PageRouteInfo<TeamDetailsRouteArgs> {
  TeamDetailsRoute({
    Key? key,
    required String teamId,
    List<PageRouteInfo>? children,
  }) : super(
          TeamDetailsRoute.name,
          args: TeamDetailsRouteArgs(
            key: key,
            teamId: teamId,
          ),
          initialChildren: children,
        );

  static const String name = 'TeamDetailsRoute';

  static const PageInfo<TeamDetailsRouteArgs> page =
      PageInfo<TeamDetailsRouteArgs>(name);
}

class TeamDetailsRouteArgs {
  const TeamDetailsRouteArgs({
    this.key,
    required this.teamId,
  });

  final Key? key;

  final String teamId;

  @override
  String toString() {
    return 'TeamDetailsRouteArgs{key: $key, teamId: $teamId}';
  }
}

/// generated route for
/// [TeamHubScreen]
class TeamHubRoute extends PageRouteInfo<void> {
  const TeamHubRoute({List<PageRouteInfo>? children})
      : super(
          TeamHubRoute.name,
          initialChildren: children,
        );

  static const String name = 'TeamHubRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}

/// generated route for
/// [VideoMainScreen]
class VideoMainRoute extends PageRouteInfo<VideoMainRouteArgs> {
  VideoMainRoute({
    Key? key,
    String? myContent,
    List<PageRouteInfo>? children,
  }) : super(
          VideoMainRoute.name,
          args: VideoMainRouteArgs(
            key: key,
            myContent: myContent,
          ),
          initialChildren: children,
        );

  static const String name = 'VideoMainRoute';

  static const PageInfo<VideoMainRouteArgs> page =
      PageInfo<VideoMainRouteArgs>(name);
}

class VideoMainRouteArgs {
  const VideoMainRouteArgs({
    this.key,
    this.myContent,
  });

  final Key? key;

  final String? myContent;

  @override
  String toString() {
    return 'VideoMainRouteArgs{key: $key, myContent: $myContent}';
  }
}

/// generated route for
/// [VideoUploadScreen]
class VideoUploadRoute extends PageRouteInfo<VideoUploadRouteArgs> {
  VideoUploadRoute({
    Key? key,
    String? challengeId,
    String? challengeTitle,
    List<PageRouteInfo>? children,
  }) : super(
          VideoUploadRoute.name,
          args: VideoUploadRouteArgs(
            key: key,
            challengeId: challengeId,
            challengeTitle: challengeTitle,
          ),
          initialChildren: children,
        );

  static const String name = 'VideoUploadRoute';

  static const PageInfo<VideoUploadRouteArgs> page =
      PageInfo<VideoUploadRouteArgs>(name);
}

class VideoUploadRouteArgs {
  const VideoUploadRouteArgs({
    this.key,
    this.challengeId,
    this.challengeTitle,
  });

  final Key? key;

  final String? challengeId;

  final String? challengeTitle;

  @override
  String toString() {
    return 'VideoUploadRouteArgs{key: $key, challengeId: $challengeId, challengeTitle: $challengeTitle}';
  }
}

/// generated route for
/// [WelcomeScreen]
class WelcomeRoute extends PageRouteInfo<void> {
  const WelcomeRoute({List<PageRouteInfo>? children})
      : super(
          WelcomeRoute.name,
          initialChildren: children,
        );

  static const String name = 'WelcomeRoute';

  static const PageInfo<void> page = PageInfo<void>(name);
}
