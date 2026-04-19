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
  final DateTime? updatedAt;

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
        updatedAt,
      ];
}
