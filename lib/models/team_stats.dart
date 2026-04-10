import 'package:flap_app/models/app_team.dart';

class TeamStats {
  final String teamId;
  final String teamName;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final Map<String, int> playerGoals;
  final List<Map<String, dynamic>> recentMatches;
  final DateTime? updatedAt;

  const TeamStats({
    required this.teamId,
    required this.teamName,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.playerGoals = const {},
    this.recentMatches = const [],
    this.updatedAt,
  });

  factory TeamStats.fromAppTeam(AppTeam team) {
    return TeamStats(
      teamId: team.id,
      teamName: team.name,
      wins: team.wins,
      draws: team.draws,
      losses: team.losses,
      goalsFor: team.goalsFor,
      goalsAgainst: team.goalsAgainst,
      playerGoals: team.playerGoals,
      recentMatches: team.recentMatches,
      updatedAt: team.updatedAt,
    );
  }

  static TeamStats empty(String teamId, {String name = ''}) {
    return TeamStats(teamId: teamId, teamName: name);
  }

  int get matches => wins + draws + losses;
  int get points => wins * 3 + draws;
  int get goalDiff => goalsFor - goalsAgainst;
}
