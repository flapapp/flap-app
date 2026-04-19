import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled,
}

class FriendRequestEntity extends Equatable {
  const FriendRequestEntity({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserAvatar,
    required this.toUserId,
    required this.toUserName,
    required this.toUserAvatar,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.message,
  });

  final String id;
  final String fromUserId;
  final String fromUserName;
  final String fromUserAvatar;
  final String toUserId;
  final String toUserName;
  final String toUserAvatar;
  final FriendRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? message;

  @override
  List<Object?> get props => [
        id,
        fromUserId,
        fromUserName,
        fromUserAvatar,
        toUserId,
        toUserName,
        toUserAvatar,
        status,
        createdAt,
        respondedAt,
        message,
      ];
}

class FriendEntity extends Equatable {
  const FriendEntity({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.city,
    required this.position,
    required this.friendsSince,
    this.isOnline = false,
    this.lastSeen,
  });

  final String userId;
  final String name;
  final String avatar;
  final double rating;
  final String city;
  final String position;
  final DateTime friendsSince;
  final bool isOnline;
  final DateTime? lastSeen;

  @override
  List<Object?> get props => [
        userId,
        name,
        avatar,
        rating,
        city,
        position,
        friendsSince,
        isOnline,
        lastSeen,
      ];
}
