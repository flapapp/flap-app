import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory TeamJoinRequest.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamJoinRequest(
      id: doc.id,
      teamId: (data['teamId'] ?? '').toString(),
      teamName: (data['teamName'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'userId': userId,
      'userName': userName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
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





