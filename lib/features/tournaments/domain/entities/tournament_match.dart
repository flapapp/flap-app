class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    required this.matchDate,
    this.homeTeamName,
    this.awayTeamName,
  });

  final String id;
  final String homeTeamId;
  final String awayTeamId;
  final String status;
  final int homeScore;
  final int awayScore;
  final DateTime? matchDate;
  final String? homeTeamName;
  final String? awayTeamName;
}
