import 'package:equatable/equatable.dart';

class TeamStatsEntity extends Equatable {
  const TeamStatsEntity({
    required this.teamId,
    required this.teamName,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    this.playerGoals = const {},
    this.recentMatches = const [],
    this.cleanSheets = 0,
    this.currentWinStreak = 0,
    this.currentUnbeatenStreak = 0,
    this.longestWinStreak = 0,
    this.recentForm = const [],
    this.lastFinishedMatchAt,
    this.updatedAt,
  });

  final String teamId;
  final String teamName;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final Map<String, int> playerGoals;
  final List<Map<String, dynamic>> recentMatches;

  /// Backed by `public.team_stats.clean_sheets`.
  final int cleanSheets;

  /// Current consecutive-win run, counted from the most-recent match backwards.
  final int currentWinStreak;

  /// Current consecutive-unbeaten run (W or D).
  final int currentUnbeatenStreak;

  /// All-time longest win streak.
  final int longestWinStreak;

  /// Last 5 outcomes ordered most-recent-first, e.g. `['W','W','D','L','W']`.
  final List<String> recentForm;

  /// `finished_at` of the latest finished team match.
  final DateTime? lastFinishedMatchAt;
  final DateTime? updatedAt;

  int get matchesPlayed => wins + draws + losses;
  int get pointsValue => wins * 3 + draws;
  int get goalDifferenceValue => goalsFor - goalsAgainst;
  double get winRate => matchesPlayed == 0 ? 0.0 : (wins / matchesPlayed) * 100.0;

  @override
  List<Object?> get props => [
        teamId,
        teamName,
        wins,
        draws,
        losses,
        goalsFor,
        goalsAgainst,
        playerGoals,
        recentMatches,
        cleanSheets,
        currentWinStreak,
        currentUnbeatenStreak,
        longestWinStreak,
        recentForm,
        lastFinishedMatchAt,
        updatedAt,
      ];
}
