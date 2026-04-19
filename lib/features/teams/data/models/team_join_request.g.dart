// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_join_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamJoinRequest _$TeamJoinRequestFromJson(Map<String, dynamic> json) =>
    TeamJoinRequest(
      id: json['id'] as String,
      teamId: json['teamId'] as String,
      teamName: json['teamName'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      status: $enumDecode(_$TeamJoinRequestStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$TeamJoinRequestToJson(TeamJoinRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'teamId': instance.teamId,
      'teamName': instance.teamName,
      'userId': instance.userId,
      'userName': instance.userName,
      'status': _$TeamJoinRequestStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$TeamJoinRequestStatusEnumMap = {
  TeamJoinRequestStatus.pending: 'pending',
  TeamJoinRequestStatus.accepted: 'accepted',
  TeamJoinRequestStatus.declined: 'declined',
};
