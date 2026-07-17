import '../../../teams/data/models/app_team.dart';
import '../../../badges/data/models/badge.dart' as app_badge;
import '../../domain/entities/player_profile_dashboard_data.dart';
import '../../domain/repositories/match_participation_stats_repository.dart';
import '../../domain/repositories/player_profile_dashboard_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/player_videos_repository.dart';
import '../../domain/repositories/profile_team_membership_repository.dart';
import '../../domain/repositories/user_badges_repository.dart';

class PlayerProfileDashboardRepositoryImpl
    implements PlayerProfileDashboardRepository {
  PlayerProfileDashboardRepositoryImpl(
    this._profileRepository,
    this._matchStats,
    this._badges,
    this._videos,
    this._teams,
  );

  final ProfileRepository _profileRepository;
  final MatchParticipationStatsRepository _matchStats;
  final UserBadgesRepository _badges;
  final PlayerVideosRepository _videos;
  final ProfileTeamMembershipRepository _teams;

  @override
  Future<PlayerProfileDashboardData> loadDashboard(String playerId) async {
    // These five reads are independent — run them concurrently instead of
    // serially. Badges and teams keep their best-effort fallback via per-future
    // catchError so one failing source can't sink the whole dashboard.
    final profileFuture = _profileRepository.fetchUserProfile(playerId);
    final statsFuture = _matchStats.loadFinishedMatchStats(playerId);
    final badgesFuture = _badges
        .getUserBadges(playerId)
        .catchError((_) => <app_badge.Badge>[]);
    final videosFuture = _videos.listVideosForUser(playerId, 10);
    final teamsFuture =
        _teams.fetchUserTeams(playerId).catchError((_) => <AppTeam>[]);

    return PlayerProfileDashboardData(
      profile: await profileFuture,
      matchStats: await statsFuture,
      badges: await badgesFuture,
      videos: await videosFuture,
      teams: await teamsFuture,
    );
  }
}
