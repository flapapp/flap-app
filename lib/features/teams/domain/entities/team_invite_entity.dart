import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum TeamInviteStatus { pending, accepted, declined }

class TeamInviteEntity extends Equatable {
  const TeamInviteEntity({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.userId,
    required this.invitedBy,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String userId;
  final String invitedBy;
  final TeamInviteStatus status;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, teamId, teamName, userId, invitedBy, status, createdAt];
}
