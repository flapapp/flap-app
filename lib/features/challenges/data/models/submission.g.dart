// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Submission _$SubmissionFromJson(Map<String, dynamic> json) => Submission(
      id: json['id'] as String,
      challengeId: json['challengeId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userAvatar: json['userAvatar'] as String,
      videoUrl: json['videoUrl'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      votes: (json['votes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
      averageRating: (json['averageRating'] as num).toDouble(),
      totalVotes: (json['totalVotes'] as num).toInt(),
      isActive: json['isActive'] as bool? ?? true,
    );

Map<String, dynamic> _$SubmissionToJson(Submission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'challengeId': instance.challengeId,
      'userId': instance.userId,
      'userName': instance.userName,
      'userAvatar': instance.userAvatar,
      'videoUrl': instance.videoUrl,
      'thumbnailUrl': instance.thumbnailUrl,
      'title': instance.title,
      'description': instance.description,
      'submittedAt': instance.submittedAt.toIso8601String(),
      'votes': instance.votes,
      'averageRating': instance.averageRating,
      'totalVotes': instance.totalVotes,
      'isActive': instance.isActive,
    };
