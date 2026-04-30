// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Match _$MatchFromJson(Map<String, dynamic> json) => Match(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      organizerId: json['organizerId'] as String,
      organizerName: json['organizerName'] as String,
      date: const IsoDateTimeConverter().fromJson(json['date']),
      time: json['time'] as String,
      location: json['location'] as String,
      city: json['city'] as String,
      coordinates: const LatLngConverter().fromJson(json['coordinates']),
      currentPlayers: (json['currentPlayers'] as num).toInt(),
      maxPlayers: (json['maxPlayers'] as num).toInt(),
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      pendingApplications: (json['pendingApplications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      rejectedApplications: (json['rejectedApplications'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      level: $enumDecode(_$MatchLevelEnumMap, json['level']),
      cost: (json['cost'] as num).toDouble(),
      autoBalance: json['autoBalance'] as bool,
      isPrivate: json['isPrivate'] as bool,
      invitedFriends: (json['invitedFriends'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      sentInvitesCount: (json['sentInvitesCount'] as num?)?.toInt() ?? 0,
      status: $enumDecode(_$MatchStatusEnumMap, json['status']),
      teamA: const MatchTeamEntityConverter().fromJson(json['teamA']),
      teamB: const MatchTeamEntityConverter().fromJson(json['teamB']),
      teams: json['teams'] == null
          ? const []
          : const MatchTeamEntityListConverter().fromJson(json['teams']),
      teamCount: (json['teamCount'] as num?)?.toInt(),
      multiTeamStats: json['multiTeamStats'] == null
          ? const []
          : const MultiTeamStatsConverter().fromJson(json['multiTeamStats']),
      isTeamMatch: json['teamMatch'] as bool? ?? false,
      teamAId: json['teamAId'] as String?,
      teamBId: json['teamBId'] as String?,
      teamAStatus: json['teamAStatus'] as String?,
      teamBStatus: json['teamBStatus'] as String?,
      teamRosters: json['teamRosters'] == null
          ? const {}
          : const TeamRostersConverter().fromJson(json['teamRosters']),
      teamRosterStatus: json['teamRosterStatus'] == null
          ? const {}
          : const TeamRosterStatusConverter()
              .fromJson(json['teamRosterStatus']),
      goalsByPlayer: json['goalsByPlayer'] == null
          ? const {}
          : const GoalsByPlayerConverter().fromJson(json['goalsByPlayer']),
      teamsReadyNotified: json['teamsReadyNotified'] as bool? ?? false,
      teamsReadyNotifiedAt: const IsoDateTimeNullableConverter()
          .fromJson(json['teamsReadyNotifiedAt']),
      coverPhotoUrl: json['coverPhotoUrl'] as String?,
      coverPhotoUpdatedAt: const IsoDateTimeNullableConverter()
          .fromJson(json['coverPhotoUpdatedAt']),
      result: const MatchResultNullableConverter().fromJson(json['result']),
      teamAScore: (json['teamAScore'] as num?)?.toInt(),
      teamBScore: (json['teamBScore'] as num?)?.toInt(),
      playerRatings: json['playerRatings'] == null
          ? const []
          : const PlayerRatingEntityListConverter()
              .fromJson(json['playerRatings']),
      createdAt: const IsoDateTimeConverter().fromJson(json['createdAt']),
      updatedAt: const IsoDateTimeConverter().fromJson(json['updatedAt']),
      startedAt:
          const IsoDateTimeNullableConverter().fromJson(json['startedAt']),
      finishedAt:
          const IsoDateTimeNullableConverter().fromJson(json['finishedAt']),
    );

Map<String, dynamic> _$MatchToJson(Match instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'organizerId': instance.organizerId,
      'organizerName': instance.organizerName,
      'date': const IsoDateTimeConverter().toJson(instance.date),
      'time': instance.time,
      'location': instance.location,
      'city': instance.city,
      'coordinates': const LatLngConverter().toJson(instance.coordinates),
      'currentPlayers': instance.currentPlayers,
      'maxPlayers': instance.maxPlayers,
      'participants': instance.participants,
      'pendingApplications': instance.pendingApplications,
      'rejectedApplications': instance.rejectedApplications,
      'level': _$MatchLevelEnumMap[instance.level]!,
      'cost': instance.cost,
      'autoBalance': instance.autoBalance,
      'isPrivate': instance.isPrivate,
      'invitedFriends': instance.invitedFriends,
      'sentInvitesCount': instance.sentInvitesCount,
      'status': _$MatchStatusEnumMap[instance.status]!,
      'teamA': const MatchTeamEntityConverter().toJson(instance.teamA),
      'teamB': const MatchTeamEntityConverter().toJson(instance.teamB),
      'teams': const MatchTeamEntityListConverter().toJson(instance.teams),
      'teamCount': instance.teamCount,
      'multiTeamStats':
          const MultiTeamStatsConverter().toJson(instance.multiTeamStats),
      'teamMatch': instance.isTeamMatch,
      'teamAId': instance.teamAId,
      'teamBId': instance.teamBId,
      'teamAStatus': instance.teamAStatus,
      'teamBStatus': instance.teamBStatus,
      'teamRosters': const TeamRostersConverter().toJson(instance.teamRosters),
      'teamRosterStatus':
          const TeamRosterStatusConverter().toJson(instance.teamRosterStatus),
      'goalsByPlayer':
          const GoalsByPlayerConverter().toJson(instance.goalsByPlayer),
      'teamsReadyNotified': instance.teamsReadyNotified,
      'teamsReadyNotifiedAt': const IsoDateTimeNullableConverter()
          .toJson(instance.teamsReadyNotifiedAt),
      'coverPhotoUrl': instance.coverPhotoUrl,
      'coverPhotoUpdatedAt': const IsoDateTimeNullableConverter()
          .toJson(instance.coverPhotoUpdatedAt),
      'result': const MatchResultNullableConverter().toJson(instance.result),
      'teamAScore': instance.teamAScore,
      'teamBScore': instance.teamBScore,
      'playerRatings': const PlayerRatingEntityListConverter()
          .toJson(instance.playerRatings),
      'createdAt': const IsoDateTimeConverter().toJson(instance.createdAt),
      'updatedAt': const IsoDateTimeConverter().toJson(instance.updatedAt),
      'startedAt':
          const IsoDateTimeNullableConverter().toJson(instance.startedAt),
      'finishedAt':
          const IsoDateTimeNullableConverter().toJson(instance.finishedAt),
    };

const _$MatchLevelEnumMap = {
  MatchLevel.beginner: 'beginner',
  MatchLevel.intermediate: 'intermediate',
  MatchLevel.advanced: 'advanced',
  MatchLevel.professional: 'professional',
};

const _$MatchStatusEnumMap = {
  MatchStatus.open: 'open',
  MatchStatus.full: 'full',
  MatchStatus.inProgress: 'inProgress',
  MatchStatus.finished: 'finished',
  MatchStatus.cancelled: 'cancelled',
};
