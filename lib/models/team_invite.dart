import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory TeamInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamInvite(
      id: doc.id,
      teamId: (data['teamId'] ?? '').toString(),
      teamName: (data['teamName'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      invitedBy: (data['invitedBy'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'userId': userId,
      'invitedBy': invitedBy,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
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









