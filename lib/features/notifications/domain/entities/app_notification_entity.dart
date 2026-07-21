import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum NotificationType {
  friendRequest,
  friendAccepted,
  challengeInvitation,
  challengeUpdate,
  challengeResult,
  challengeCompleted,
  videoVote,
  matchInvite,
  matchFinished,
  badgeEarned,
  badgeEndorsed,
  coinsEarned,
  ratingRequest,
  ratingChanged,
  teamInvite,
  teamMatchRequest,
  teamMatchReady,
  teamRosterInvite,
  teamJoinRequest,
  subscriptionUpdate,
  matchUpdate,
  teamUpdate,
  videoInteraction,
}

class AppNotificationEntity extends Equatable {
  const AppNotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.createdAt,
    this.isRead = false,
    this.imageUrl,
    this.actionUrl,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;
  final String? imageUrl;
  final String? actionUrl;

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        title,
        message,
        data,
        createdAt,
        isRead,
        imageUrl,
        actionUrl,
      ];
}
