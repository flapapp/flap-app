class TournamentSummary {
  const TournamentSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.maxTeams,
  });

  final String id;
  final String name;
  final String type;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? maxTeams;
}
