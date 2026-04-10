enum TeamJoinRequestStatus { pending, accepted, declined }

class TeamJoinRequest {
  final String id;
  final String teamId;
  final String teamName;
  final String userId;
  final String userName;
  final TeamJoinRequestStatus status;
  final DateTime createdAt;

  const TeamJoinRequest({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.userName,
    required this.status,
    required this.createdAt,
  });

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory TeamJoinRequest.fromSupabaseRow(Map<String, dynamic> row) {
    return TeamJoinRequest(
      id: row['id'].toString(),
      teamId: (row['team_id'] ?? '').toString(),
      teamName: (row['team_name'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      userName: (row['user_name'] ?? '').toString(),
      status: _statusFromString((row['status'] ?? 'pending').toString()),
      createdAt: _ts(row['created_at']),
    );
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'team_id': teamId,
      'team_name': teamName,
      'user_id': userId,
      'user_name': userName,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static TeamJoinRequestStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return TeamJoinRequestStatus.accepted;
      case 'declined':
        return TeamJoinRequestStatus.declined;
      default:
        return TeamJoinRequestStatus.pending;
    }
  }
}
