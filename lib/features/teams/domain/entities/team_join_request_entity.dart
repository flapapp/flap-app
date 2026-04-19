import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TeamJoinRequestStatus { pending, accepted, declined }

class TeamJoinRequestEntity extends Equatable {
  const TeamJoinRequestEntity({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.userName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String userId;
  final String userName;
  final TeamJoinRequestStatus status;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, teamId, teamName, userId, userName, status, createdAt];
}
