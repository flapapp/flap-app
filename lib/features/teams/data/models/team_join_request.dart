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
      dynamic doc) {
    final id = (doc.id ?? '').toString();
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map? ?? const {});
    DateTime parseDate(dynamic v) {
      if (v is DateTime) return v;
      final parsed = DateTime.tryParse((v ?? '').toString());
      return parsed ?? DateTime.now();
    }
    return TeamJoinRequest(
      id: id,
      teamId: (data['teamId'] ?? '').toString(),
      teamName: (data['teamName'] ?? '').toString(),
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      status: _statusFromString((data['status'] ?? 'pending').toString()),
      createdAt: parseDate(data['createdAt']),
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
      'createdAt': createdAt.toIso8601String(),
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





