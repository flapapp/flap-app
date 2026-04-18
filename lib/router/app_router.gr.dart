// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AdminScreen]
class AdminRoute extends PageRouteInfo<void> {
  const AdminRoute({List<PageRouteInfo>? children})
      : super(
          AdminRoute.name,
          initialChildren: children,
        );

  static const String name = 'AdminRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AdminScreen();
    },
  );
}

/// generated route for
/// [AuthBootstrapScreen]
class AuthBootstrapRoute extends PageRouteInfo<void> {
  const AuthBootstrapRoute({List<PageRouteInfo>? children})
      : super(
          AuthBootstrapRoute.name,
          initialChildren: children,
        );

  static const String name = 'AuthBootstrapRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AuthBootstrapScreen();
    },
  );
}

/// generated route for
/// [BadgesStoreScreen]
class BadgesStoreRoute extends PageRouteInfo<void> {
  const BadgesStoreRoute({List<PageRouteInfo>? children})
      : super(
          BadgesStoreRoute.name,
          initialChildren: children,
        );

  static const String name = 'BadgesStoreRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return BadgesStoreScreen();
    },
  );
}

/// generated route for
/// [ChallengeCompletionScreen]
class ChallengeCompletionRoute
    extends PageRouteInfo<ChallengeCompletionRouteArgs> {
  ChallengeCompletionRoute({
    Key? key,
    required String challengeId,
    List<PageRouteInfo>? children,
  }) : super(
          ChallengeCompletionRoute.name,
          args: ChallengeCompletionRouteArgs(
            key: key,
            challengeId: challengeId,
          ),
          initialChildren: children,
        );

  static const String name = 'ChallengeCompletionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChallengeCompletionRouteArgs>();
      return ChallengeCompletionScreen(
        key: args.key,
        challengeId: args.challengeId,
      );
    },
  );
}

class ChallengeCompletionRouteArgs {
  const ChallengeCompletionRouteArgs({
    this.key,
    required this.challengeId,
  });

  final Key? key;

  final String challengeId;

  @override
  String toString() {
    return 'ChallengeCompletionRouteArgs{key: $key, challengeId: $challengeId}';
  }
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return ChallengeCreateScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChallengeDetailsRouteArgs>();
      return ChallengeDetailsScreen(
        key: args.key,
        challenge: args.challenge,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return ChallengeListScreen();
    },
  );
}

/// generated route for
/// [ChallengeVideoPlayerScreen]
class ChallengeVideoPlayerRoute
    extends PageRouteInfo<ChallengeVideoPlayerRouteArgs> {
  ChallengeVideoPlayerRoute({
    Key? key,
    required String videoUrl,
    required String title,
    required String authorName,
    required String challengeId,
    required String submissionId,
    String? thumbnailUrl,
    List<PageRouteInfo>? children,
  }) : super(
          ChallengeVideoPlayerRoute.name,
          args: ChallengeVideoPlayerRouteArgs(
            key: key,
            videoUrl: videoUrl,
            title: title,
            authorName: authorName,
            challengeId: challengeId,
            submissionId: submissionId,
            thumbnailUrl: thumbnailUrl,
          ),
          initialChildren: children,
        );

  static const String name = 'ChallengeVideoPlayerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChallengeVideoPlayerRouteArgs>();
      return ChallengeVideoPlayerScreen(
        key: args.key,
        videoUrl: args.videoUrl,
        title: args.title,
        authorName: args.authorName,
        challengeId: args.challengeId,
        submissionId: args.submissionId,
        thumbnailUrl: args.thumbnailUrl,
      );
    },
  );
}

class ChallengeVideoPlayerRouteArgs {
  const ChallengeVideoPlayerRouteArgs({
    this.key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.challengeId,
    required this.submissionId,
    this.thumbnailUrl,
  });

  final Key? key;

  final String videoUrl;

  final String title;

  final String authorName;

  final String challengeId;

  final String submissionId;

  final String? thumbnailUrl;

  @override
  String toString() {
    return 'ChallengeVideoPlayerRouteArgs{key: $key, videoUrl: $videoUrl, title: $title, authorName: $authorName, challengeId: $challengeId, submissionId: $submissionId, thumbnailUrl: $thumbnailUrl}';
  }
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CreateMatchScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return FriendsScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const IntroVideoScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LoginScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MatchDetailsRouteArgs>();
      return MatchDetailsScreen(
        key: args.key,
        match: args.match,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MatchManagementRouteArgs>();
      return MatchManagementScreen(
        key: args.key,
        match: args.match,
        initialTabIndex: args.initialTabIndex,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MatchRatingRouteArgs>();
      return MatchRatingScreen(
        key: args.key,
        match: args.match,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<MatchesRouteArgs>(orElse: () => const MatchesRouteArgs());
      return MatchesScreen(
        key: args.key,
        initialTabIndex: args.initialTabIndex,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ModeSelectionScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NotificationsScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PlayerProfileRouteArgs>();
      return PlayerProfileScreen(
        key: args.key,
        playerId: args.playerId,
        playerName: args.playerName,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ProfileCreationRouteArgs>(
          orElse: () => const ProfileCreationRouteArgs());
      return ProfileCreationScreen(
        key: args.key,
        isEditing: args.isEditing,
      );
    },
  );
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
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
      : super(
          ProfileRoute.name,
          initialChildren: children,
        );

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfileScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfileSettingsScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return RatingsScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RegisterScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const StatsScreen();
    },
  );
}

/// generated route for
/// [SubscriptionScreen]
class SubscriptionRoute extends PageRouteInfo<void> {
  const SubscriptionRoute({List<PageRouteInfo>? children})
      : super(
          SubscriptionRoute.name,
          initialChildren: children,
        );

  static const String name = 'SubscriptionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return SubscriptionScreen();
    },
  );
}

/// generated route for
/// [TeamCreateScreen]
class TeamCreateRoute extends PageRouteInfo<TeamCreateRouteArgs> {
  TeamCreateRoute({
    Key? key,
    required int existingTeams,
    List<PageRouteInfo>? children,
  }) : super(
          TeamCreateRoute.name,
          args: TeamCreateRouteArgs(
            key: key,
            existingTeams: existingTeams,
          ),
          initialChildren: children,
        );

  static const String name = 'TeamCreateRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TeamCreateRouteArgs>();
      return TeamCreateScreen(
        key: args.key,
        existingTeams: args.existingTeams,
      );
    },
  );
}

class TeamCreateRouteArgs {
  const TeamCreateRouteArgs({
    this.key,
    required this.existingTeams,
  });

  final Key? key;

  final int existingTeams;

  @override
  String toString() {
    return 'TeamCreateRouteArgs{key: $key, existingTeams: $existingTeams}';
  }
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TeamDetailsRouteArgs>();
      return TeamDetailsScreen(
        key: args.key,
        teamId: args.teamId,
      );
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TeamHubScreen();
    },
  );
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<VideoMainRouteArgs>(
          orElse: () => const VideoMainRouteArgs());
      return VideoMainScreen(
        key: args.key,
        myContent: args.myContent,
      );
    },
  );
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
/// [VideoPlayerScreen]
class VideoPlayerRoute extends PageRouteInfo<VideoPlayerRouteArgs> {
  VideoPlayerRoute({
    Key? key,
    required String videoUrl,
    required String title,
    required String authorName,
    required String videoId,
    String? challengeId,
    String? submissionUserId,
    bool autoOpenRating = false,
    List<PageRouteInfo>? children,
  }) : super(
          VideoPlayerRoute.name,
          args: VideoPlayerRouteArgs(
            key: key,
            videoUrl: videoUrl,
            title: title,
            authorName: authorName,
            videoId: videoId,
            challengeId: challengeId,
            submissionUserId: submissionUserId,
            autoOpenRating: autoOpenRating,
          ),
          initialChildren: children,
        );

  static const String name = 'VideoPlayerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<VideoPlayerRouteArgs>();
      return VideoPlayerScreen(
        key: args.key,
        videoUrl: args.videoUrl,
        title: args.title,
        authorName: args.authorName,
        videoId: args.videoId,
        challengeId: args.challengeId,
        submissionUserId: args.submissionUserId,
        autoOpenRating: args.autoOpenRating,
      );
    },
  );
}

class VideoPlayerRouteArgs {
  const VideoPlayerRouteArgs({
    this.key,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.videoId,
    this.challengeId,
    this.submissionUserId,
    this.autoOpenRating = false,
  });

  final Key? key;

  final String videoUrl;

  final String title;

  final String authorName;

  final String videoId;

  final String? challengeId;

  final String? submissionUserId;

  final bool autoOpenRating;

  @override
  String toString() {
    return 'VideoPlayerRouteArgs{key: $key, videoUrl: $videoUrl, title: $title, authorName: $authorName, videoId: $videoId, challengeId: $challengeId, submissionUserId: $submissionUserId, autoOpenRating: $autoOpenRating}';
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<VideoUploadRouteArgs>(
          orElse: () => const VideoUploadRouteArgs());
      return VideoUploadScreen(
        key: args.key,
        challengeId: args.challengeId,
        challengeTitle: args.challengeTitle,
      );
    },
  );
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
/// [VideosScreen]
class VideosRoute extends PageRouteInfo<VideosRouteArgs> {
  VideosRoute({
    Key? key,
    bool showOnlyMyVideos = false,
    List<PageRouteInfo>? children,
  }) : super(
          VideosRoute.name,
          args: VideosRouteArgs(
            key: key,
            showOnlyMyVideos: showOnlyMyVideos,
          ),
          initialChildren: children,
        );

  static const String name = 'VideosRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args =
          data.argsAs<VideosRouteArgs>(orElse: () => const VideosRouteArgs());
      return VideosScreen(
        key: args.key,
        showOnlyMyVideos: args.showOnlyMyVideos,
      );
    },
  );
}

class VideosRouteArgs {
  const VideosRouteArgs({
    this.key,
    this.showOnlyMyVideos = false,
  });

  final Key? key;

  final bool showOnlyMyVideos;

  @override
  String toString() {
    return 'VideosRouteArgs{key: $key, showOnlyMyVideos: $showOnlyMyVideos}';
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

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WelcomeScreen();
    },
  );
}
