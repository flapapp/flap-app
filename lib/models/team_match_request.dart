enum TeamMatchRequestStatus { pending, accepted, declined }

class TeamMatchRequest {
  final String id;
  final String matchId;
  final String teamId;
  final String opponentTeamId;
  final String opponentName;
  final String createdBy;
  final TeamMatchRequestStatus status;
  final DateTime createdAt;
  final List<String> proposedRoster;

  const TeamMatchRequest({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.opponentTeamId,
    required this.opponentName,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    this.proposedRoster = const [],
  });

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static List<String> _uuidList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  factory TeamMatchRequest.fromSupabaseRow(Map<String, dynamic> row) {
    return TeamMatchRequest(
      id: row['id'].toString(),
      matchId: (row['match_id'] ?? '').toString(),
      teamId: (row['team_id'] ?? '').toString(),
      opponentTeamId: (row['opponent_team_id'] ?? '').toString(),
      opponentName: (row['opponent_name'] ?? '').toString(),
      createdBy: (row['created_by'] ?? '').toString(),
      status: _statusFromString((row['status'] ?? 'pending').toString()),
      createdAt: _ts(row['created_at']),
      proposedRoster: _uuidList(row['proposed_roster']),
    );
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'match_id': matchId,
      'team_id': teamId,
      'opponent_team_id': opponentTeamId,
      'opponent_name': opponentName,
      'created_by': createdBy,
      'status': status.name,
      'proposed_roster': proposedRoster,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static TeamMatchRequestStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return TeamMatchRequestStatus.accepted;
      case 'declined':
        return TeamMatchRequestStatus.declined;
      default:
        return TeamMatchRequestStatus.pending;
    }
  }
}
