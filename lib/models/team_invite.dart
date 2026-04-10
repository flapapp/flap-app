enum TeamInviteStatus { pending, accepted, declined }

class TeamInvite {
  final String id;
  final String teamId;
  final String teamName;
  final String userId;
  final String invitedBy;
  final TeamInviteStatus status;
  final DateTime createdAt;

  const TeamInvite({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
  });

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory TeamInvite.fromSupabaseRow(Map<String, dynamic> row) {
    return TeamInvite(
      id: row['id'].toString(),
      teamId: (row['team_id'] ?? '').toString(),
      teamName: (row['team_name'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      invitedBy: (row['invited_by'] ?? '').toString(),
      status: _statusFromString((row['status'] ?? 'pending').toString()),
      createdAt: _ts(row['created_at']),
    );
  }

  Map<String, dynamic> toSupabaseInsert() {
    return {
      'team_id': teamId,
      'team_name': teamName,
      'user_id': userId,
      'invited_by': invitedBy,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static TeamInviteStatus _statusFromString(String value) {
    switch (value) {
      case 'accepted':
        return TeamInviteStatus.accepted;
      case 'declined':
        return TeamInviteStatus.declined;
      default:
        return TeamInviteStatus.pending;
    }
  }
}
