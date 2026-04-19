// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendRequest _$FriendRequestFromJson(Map<String, dynamic> json) =>
    FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      fromUserAvatar: json['fromUserAvatar'] as String,
      toUserId: json['toUserId'] as String,
      toUserName: json['toUserName'] as String,
      toUserAvatar: json['toUserAvatar'] as String,
      status: $enumDecode(_$FriendRequestStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      respondedAt: json['respondedAt'] == null
          ? null
          : DateTime.parse(json['respondedAt'] as String),
      message: json['message'] as String?,
    );

Map<String, dynamic> _$FriendRequestToJson(FriendRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromUserId': instance.fromUserId,
      'fromUserName': instance.fromUserName,
      'fromUserAvatar': instance.fromUserAvatar,
      'toUserId': instance.toUserId,
      'toUserName': instance.toUserName,
      'toUserAvatar': instance.toUserAvatar,
      'status': _$FriendRequestStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'respondedAt': instance.respondedAt?.toIso8601String(),
      'message': instance.message,
    };

const _$FriendRequestStatusEnumMap = {
  FriendRequestStatus.pending: 'pending',
  FriendRequestStatus.accepted: 'accepted',
  FriendRequestStatus.declined: 'declined',
  FriendRequestStatus.cancelled: 'cancelled',
};

Friend _$FriendFromJson(Map<String, dynamic> json) => Friend(
      userId: json['userId'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String,
      rating: (json['rating'] as num).toDouble(),
      city: json['city'] as String,
      position: json['position'] as String,
      friendsSince: DateTime.parse(json['friendsSince'] as String),
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeen: json['lastSeen'] == null
          ? null
          : DateTime.parse(json['lastSeen'] as String),
    );

Map<String, dynamic> _$FriendToJson(Friend instance) => <String, dynamic>{
      'userId': instance.userId,
      'name': instance.name,
      'avatar': instance.avatar,
      'rating': instance.rating,
      'city': instance.city,
      'position': instance.position,
      'friendsSince': instance.friendsSince.toIso8601String(),
      'isOnline': instance.isOnline,
      'lastSeen': instance.lastSeen?.toIso8601String(),
    };
