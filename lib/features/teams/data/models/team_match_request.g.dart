// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_match_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeamMatchRequest _$TeamMatchRequestFromJson(Map<String, dynamic> json) =>
    TeamMatchRequest(
      id: json['id'] as String,
      matchId: json['matchId'] as String,
      teamId: json['teamId'] as String,
      opponentTeamId: json['opponentTeamId'] as String,
      opponentName: json['opponentName'] as String,
      createdBy: json['createdBy'] as String,
      status: $enumDecode(_$TeamMatchRequestStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      proposedRoster: (json['proposedRoster'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$TeamMatchRequestToJson(TeamMatchRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'matchId': instance.matchId,
      'teamId': instance.teamId,
      'opponentTeamId': instance.opponentTeamId,
      'opponentName': instance.opponentName,
      'createdBy': instance.createdBy,
      'status': _$TeamMatchRequestStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'proposedRoster': instance.proposedRoster,
    };

const _$TeamMatchRequestStatusEnumMap = {
  TeamMatchRequestStatus.pending: 'pending',
  TeamMatchRequestStatus.accepted: 'accepted',
  TeamMatchRequestStatus.declined: 'declined',
};
