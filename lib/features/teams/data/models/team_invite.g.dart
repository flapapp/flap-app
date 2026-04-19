// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamInvite _$TeamInviteFromJson(Map<String, dynamic> json) => TeamInvite(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      teamName: json['teamName'] as String,
      userId: json['userId'] as String,
      invitedBy: json['invitedBy'] as String,
      status: $enumDecode(_$TeamInviteStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$TeamInviteToJson(TeamInvite instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamId': instance.teamId,
      'teamName': instance.teamName,
      'userId': instance.userId,
      'invitedBy': instance.invitedBy,
      'status': _$TeamInviteStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$TeamInviteStatusEnumMap = {
  TeamInviteStatus.pending: 'pending',
  TeamInviteStatus.accepted: 'accepted',
  TeamInviteStatus.declined: 'declined',
};
