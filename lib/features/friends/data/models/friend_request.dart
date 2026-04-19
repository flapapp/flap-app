import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/friend_request_entity.dart';

export '../../domain/entities/friend_request_entity.dart';

part 'friend_request.g.dart';

@JsonSerializable(explicitToJson: true)
class FriendRequest extends FriendRequestEntity {
  const FriendRequest({
    required super.id,
    required super.fromUserId,
    required super.fromUserName,
    required super.fromUserAvatar,
    required super.toUserId,
    required super.toUserName,
    required super.toUserAvatar,
    required super.status,
    required super.createdAt,
    super.respondedAt,
    super.message,
  });

  // Factory constructor from Firestore
  factory FriendRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return FriendRequest(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserName: data['fromUserName'] ?? '',
      fromUserAvatar: data['fromUserAvatar'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserName: data['toUserName'] ?? '',
      toUserAvatar: data['toUserAvatar'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null 
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      message: data['message'],
    );
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRequestToJson(this);

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserAvatar': fromUserAvatar,
      'toUserId': toUserId,
      'toUserName': toUserName,
      'toUserAvatar': toUserAvatar,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null 
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'message': message,
    };
  }

  // Copy with changes
  FriendRequest copyWith({
    String? id,
    String? fromUserId,
    String? fromUserName,
    String? fromUserAvatar,
    String? toUserId,
    String? toUserName,
    String? toUserAvatar,
    FriendRequestStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? message,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserName: fromUserName ?? this.fromUserName,
      fromUserAvatar: fromUserAvatar ?? this.fromUserAvatar,
      toUserId: toUserId ?? this.toUserId,
      toUserName: toUserName ?? this.toUserName,
      toUserAvatar: toUserAvatar ?? this.toUserAvatar,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
    );
  }

  // Getters for status
  bool get isPending => status == FriendRequestStatus.pending;
  bool get isAccepted => status == FriendRequestStatus.accepted;
  bool get isDeclined => status == FriendRequestStatus.declined;
  bool get isCancelled => status == FriendRequestStatus.cancelled;

  // Status text
  String get statusText {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'Очікує відповіді';
      case FriendRequestStatus.accepted:
        return 'Прийнято';
      case FriendRequestStatus.declined:
        return 'Відхилено';
      case FriendRequestStatus.cancelled:
        return 'Скасовано';
    }
  }

  // Status color
  int get statusColor {
    switch (status) {
      case FriendRequestStatus.pending:
        return 0xFFFF9800; // Orange
      case FriendRequestStatus.accepted:
        return 0xFF4CAF50; // Green
      case FriendRequestStatus.declined:
        return 0xFFF44336; // Red
      case FriendRequestStatus.cancelled:
        return 0xFF9E9E9E; // Grey
    }
  }

  // Time ago text
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} дн. тому';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} год. тому';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} хв. тому';
    } else {
      return 'Щойно';
    }
  }
}

@JsonSerializable(explicitToJson: true)
class Friend extends FriendEntity {
  const Friend({
    required super.userId,
    required super.name,
    required super.avatar,
    required super.rating,
    required super.city,
    required super.position,
    required super.friendsSince,
    super.isOnline = false,
    super.lastSeen,
  });

  factory Friend.fromJson(Map<String, dynamic> json) =>
      _$FriendFromJson(json);

  Map<String, dynamic> toJson() => _$FriendToJson(this);

  // Factory constructor from user data
  factory Friend.fromUserData(Map<String, dynamic> userData, DateTime friendsSince) {
    return Friend(
      userId: userData['id'] ?? '',
      name: userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? tr('il_b512d97e7c'),
      avatar: userData['avatarUrl'] ?? userData['avatar'] ?? '', // Спочатку перевіряємо avatarUrl, потім avatar
      rating: (userData['rating'] ?? 0.0).toDouble(),
      city: userData['city'] ?? tr('il_2491fe94a7'),
      position: userData['position'] ?? 'player',
      friendsSince: friendsSince,
      isOnline: userData['isOnline'] ?? false,
      lastSeen: userData['lastSeen'] != null 
          ? (userData['lastSeen'] as Timestamp).toDate()
          : null,
    );
  }

  // Rating display
  String get ratingDisplay => rating.toStringAsFixed(1);

  // Rating stars
  String get ratingStars {
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;
    
    String stars = '⭐' * fullStars;
    if (hasHalfStar) stars += '⭐';
    
    return stars;
  }

  // Position display
  String get positionDisplay {
    return _getLocalizedPosition(position);
  }

  static String _getLocalizedPosition(String position) {
    switch (position.toLowerCase()) {
      case 'goalkeeper':
        return tr('il_aaa1d36c11');
      case 'defender':
        return tr('il_98dd178c49');
      case 'midfielder':
        return tr('il_1f9f85e17c');
      case 'forward':
        return tr('il_34b28d645d');
      default:
        return tr('il_188a0d7d57');
    }
  }

  // Online status
  String get onlineStatus {
    if (isOnline) return tr('il_0d21bd5202');
    
    if (lastSeen == null) return tr('il_052f81f388');
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen!);
    
    if (difference.inDays > 0) {
      final days = difference.inDays;
      return tr('il_e345f3fbc6');
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return tr('il_71260c47e0');
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return tr('il_031a7ac35e');
    } else {
      return tr('il_66f53417d3');
    }
  }

  // Online status color
  int get onlineStatusColor {
    if (isOnline) return 0xFF4CAF50; // Green
    
    if (lastSeen == null) return 0xFF9E9E9E; // Grey
    
    final difference = DateTime.now().difference(lastSeen!);
    if (difference.inHours < 1) return 0xFFFF9800; // Orange
    
    return 0xFF9E9E9E; // Grey
  }
}
