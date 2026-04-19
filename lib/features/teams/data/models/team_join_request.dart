import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/team_join_request_entity.dart';

export '../../domain/entities/team_join_request_entity.dart';

part 'team_join_request.g.dart';

@JsonSerializable(explicitToJson: true)
class TeamJoinRequest extends TeamJoinRequestEntity {
  const TeamJoinRequest({
    required super.id,
    required super.teamId,
    required super.teamName,
    required super.userId,
    required super.userName,
    required super.status,
    required super.createdAt,
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

  factory TeamJoinRequest.fromJson(Map<String, dynamic> json) =>
      _$TeamJoinRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TeamJoinRequestToJson(this);

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





