// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Challenge _$ChallengeFromJson(Map<String, dynamic> json) => Challenge(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: $enumDecode(_$ChallengeTypeEnumMap, json['type']),
      audience: $enumDecode(_$ChallengeAudienceEnumMap, json['audience']),
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String,
      creatorVideoUrl: json['creatorVideoUrl'] as String?,
      city: json['city'] as String,
      entryFee: (json['entryFee'] as num).toInt(),
      duration: (json['duration'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      startDate: DateTime.parse(json['startDate'] as String),
      submissionDeadline: DateTime.parse(json['submissionDeadline'] as String),
      votingDeadline: DateTime.parse(json['votingDeadline'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: $enumDecode(_$ChallengeStatusEnumMap, json['status']),
      maxParticipants: (json['maxParticipants'] as num).toInt(),
      currentParticipants: (json['currentParticipants'] as num).toInt(),
      prizePool: (json['prizePool'] as num).toDouble(),
      participants: (json['participants'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      submissions: (json['submissions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      votes: (json['votes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      detailedVotes: (json['detailedVotes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry(k, (e as num).toDouble()),
            )),
      ),
      winners:
          (json['winners'] as List<dynamic>).map((e) => e as String).toList(),
      finalScores: (json['finalScores'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      winnerPrizes: (json['winnerPrizes'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      isActive: json['isActive'] as bool,
      imageUrl: json['imageUrl'] as String?,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$ChallengeToJson(Challenge instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'type': _$ChallengeTypeEnumMap[instance.type]!,
      'audience': _$ChallengeAudienceEnumMap[instance.audience]!,
      'creatorId': instance.creatorId,
      'creatorName': instance.creatorName,
      'creatorVideoUrl': instance.creatorVideoUrl,
      'city': instance.city,
      'entryFee': instance.entryFee,
      'duration': instance.duration,
      'createdAt': instance.createdAt.toIso8601String(),
      'startDate': instance.startDate.toIso8601String(),
      'submissionDeadline': instance.submissionDeadline.toIso8601String(),
      'votingDeadline': instance.votingDeadline.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'status': _$ChallengeStatusEnumMap[instance.status]!,
      'maxParticipants': instance.maxParticipants,
      'currentParticipants': instance.currentParticipants,
      'prizePool': instance.prizePool,
      'participants': instance.participants,
      'submissions': instance.submissions,
      'votes': instance.votes,
      'detailedVotes': instance.detailedVotes,
      'winners': instance.winners,
      'finalScores': instance.finalScores,
      'winnerPrizes': instance.winnerPrizes,
      'isActive': instance.isActive,
      'imageUrl': instance.imageUrl,
      'tags': instance.tags,
    };

const _$ChallengeTypeEnumMap = {
  ChallengeType.goal: 'goal',
  ChallengeType.shotPower: 'shotPower',
  ChallengeType.pass: 'pass',
  ChallengeType.longPass: 'longPass',
  ChallengeType.dribbling: 'dribbling',
  ChallengeType.tackle: 'tackle',
  ChallengeType.defending: 'defending',
  ChallengeType.penalty: 'penalty',
  ChallengeType.save: 'save',
  ChallengeType.wall: 'wall',
  ChallengeType.strategy: 'strategy',
  ChallengeType.trick: 'trick',
  ChallengeType.other: 'other',
};

const _$ChallengeAudienceEnumMap = {
  ChallengeAudience.friends: 'friends',
  ChallengeAudience.city: 'city',
  ChallengeAudience.country: 'country',
  ChallengeAudience.world: 'world',
};

const _$ChallengeStatusEnumMap = {
  ChallengeStatus.recruiting: 'recruiting',
  ChallengeStatus.submission: 'submission',
  ChallengeStatus.voting: 'voting',
  ChallengeStatus.completed: 'completed',
};
