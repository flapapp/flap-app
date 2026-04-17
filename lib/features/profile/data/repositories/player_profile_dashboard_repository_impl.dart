import '../../../../models/app_team.dart';
import '../../../../models/badge.dart' as app_badge;
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
    final profile = await _profileRepository.fetchUserProfile(playerId);

    final stats = await _matchStats.loadFinishedMatchStats(playerId);

    var badges = <app_badge.Badge>[];
    try {
      badges = await _badges.getUserBadges(playerId);
    } catch (_) {}

    final videoMaps = await _videos.listVideosForUser(playerId, 10);

    var teams = <AppTeam>[];
    try {
      teams = await _teams.fetchUserTeams(playerId);
    } catch (_) {}

    return PlayerProfileDashboardData(
      profile: profile,
      matchStats: stats,
      badges: badges,
      videos: videoMaps,
      teams: teams,
    );
  }
}
