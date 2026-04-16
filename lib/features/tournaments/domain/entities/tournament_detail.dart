/// Full tournament row for detail / join flows.
class TournamentDetail {
  const TournamentDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.maxTeams,
    this.rules,
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
  final Map<String, dynamic>? rules;
}
