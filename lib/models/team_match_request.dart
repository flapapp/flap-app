import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory TeamMatchRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamMatchRequest(
      id: doc.id,
      matchId: (data['matchId'] ?? '').toString(),
      teamId: (data['teamId'] ?? '').toString(),
      opponentTeamId: (data['opponentTeamId'] ?? '').toString(),
      opponentName: (data['opponentName'] ?? '').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      proposedRoster: List<String>.from(data['proposedRoster'] ?? const []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'matchId': matchId,
      'teamId': teamId,
      'opponentTeamId': opponentTeamId,
      'opponentName': opponentName,
      'createdBy': createdBy,
      'status': status.name,
      'proposedRoster': proposedRoster,
      'createdAt': Timestamp.fromDate(createdAt),
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








