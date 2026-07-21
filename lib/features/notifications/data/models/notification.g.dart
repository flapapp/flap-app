// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: $enumDecode(_$NotificationTypeEnumMap, json['type']),
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      actionUrl: json['actionUrl'] as String?,
    );

Map<String, dynamic> _$AppNotificationToJson(AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'type': _$NotificationTypeEnumMap[instance.type]!,
      'title': instance.title,
      'message': instance.message,
      'data': instance.data,
      'createdAt': instance.createdAt.toIso8601String(),
      'isRead': instance.isRead,
      'imageUrl': instance.imageUrl,
      'actionUrl': instance.actionUrl,
    };

const _$NotificationTypeEnumMap = {
  NotificationType.friendRequest: 'friendRequest',
  NotificationType.friendAccepted: 'friendAccepted',
  NotificationType.challengeInvitation: 'challengeInvitation',
  NotificationType.challengeUpdate: 'challengeUpdate',
  NotificationType.challengeResult: 'challengeResult',
  NotificationType.challengeCompleted: 'challengeCompleted',
  NotificationType.videoVote: 'videoVote',
  NotificationType.matchInvite: 'matchInvite',
  NotificationType.matchFinished: 'matchFinished',
  NotificationType.badgeEarned: 'badgeEarned',
  NotificationType.badgeEndorsed: 'badgeEndorsed',
  NotificationType.coinsEarned: 'coinsEarned',
  NotificationType.ratingRequest: 'ratingRequest',
  NotificationType.ratingChanged: 'ratingChanged',
  NotificationType.teamInvite: 'teamInvite',
  NotificationType.teamMatchRequest: 'teamMatchRequest',
  NotificationType.teamMatchReady: 'teamMatchReady',
  NotificationType.teamRosterInvite: 'teamRosterInvite',
  NotificationType.teamJoinRequest: 'teamJoinRequest',
  NotificationType.subscriptionUpdate: 'subscriptionUpdate',
  NotificationType.matchUpdate: 'matchUpdate',
  NotificationType.teamUpdate: 'teamUpdate',
  NotificationType.videoInteraction: 'videoInteraction',
};
