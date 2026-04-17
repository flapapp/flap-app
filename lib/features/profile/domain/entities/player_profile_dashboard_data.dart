import '../../../../models/app_team.dart';
import '../../../../models/badge.dart' as app_badge;
import 'user_profile.dart';

/// Initial payload for the public player profile screen.
class PlayerProfileDashboardData {
  const PlayerProfileDashboardData({
    required this.profile,
    required this.matchStats,
    required this.badges,
    required this.videos,
    required this.teams,
  });

  final UserProfile? profile;
  final Map<String, dynamic> matchStats;
  final List<app_badge.Badge> badges;
  final List<Map<String, dynamic>> videos;
  final List<AppTeam> teams;
}
