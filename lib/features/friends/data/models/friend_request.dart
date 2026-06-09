import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/core/supabase/supabase_date.dart';

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

  factory FriendRequest.fromSupabase(Map<String, dynamic> row) {
    final fromP = row['from_user_profile'];
    final toP = row['to_user_profile'];
    final fromMap = fromP is Map<String, dynamic>
        ? fromP
        : fromP is Map
            ? Map<String, dynamic>.from(fromP)
            : <String, dynamic>{};
    final toMap = toP is Map<String, dynamic>
        ? toP
        : toP is Map
            ? Map<String, dynamic>.from(toP)
            : <String, dynamic>{};

    String pickName(Map<String, dynamic> p) {
      final dn = p['display_name'] as String?;
      if (dn != null && dn.isNotEmpty) return dn;
      final em = p['email'] as String?;
      if (em != null && em.contains('@')) return em.split('@').first;
      return '';
    }

    return FriendRequest(
      id: row['id'] as String,
      fromUserId: row['from_user_id'] as String,
      fromUserName: pickName(fromMap),
      fromUserAvatar: (fromMap['avatar_url'] ?? '') as String,
      toUserId: row['to_user_id'] as String,
      toUserName: pickName(toMap),
      toUserAvatar: (toMap['avatar_url'] ?? '') as String,
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == row['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: asDateTime(row['created_at']),
      respondedAt: asDateTimeOrNull(row['responded_at']),
      message: row['message'] as String?,
    );
  }

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FriendRequestToJson(this);

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
        return tr('match_invite_status_pending');
      case FriendRequestStatus.accepted:
        return tr('match_invite_status_accepted');
      case FriendRequestStatus.declined:
        return tr('match_invite_status_declined');
      case FriendRequestStatus.cancelled:
        return tr('match_invite_status_cancelled');
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

  // Time ago text (same keys as [Friend.onlineStatus])
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return tr(
        'il_e345f3fbc6',
        namedArgs: {'days': '${difference.inDays}'},
      );
    }
    if (difference.inHours > 0) {
      return tr(
        'il_71260c47e0',
        namedArgs: {'hours': '${difference.inHours}'},
      );
    }
    if (difference.inMinutes > 0) {
      return tr(
        'il_031a7ac35e',
        namedArgs: {'minutes': '${difference.inMinutes}'},
      );
    }
    return tr('il_66f53417d3');
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
    final ratingRaw = userData['rating'] ??
        userData['overall_rating'] ??
        userData['overallRating'] ??
        0.0;
    return Friend(
      userId: userData['id']?.toString() ?? '',
      name: userData['displayName'] ??
          userData['display_name'] ??
          userData['name'] ??
          userData['email']?.toString().split('@').first ??
          tr('il_b512d97e7c'),
      avatar: userData['avatarUrl'] ??
          userData['avatar_url'] ??
          userData['avatar'] ??
          '',
      rating: (ratingRaw is num ? ratingRaw : double.tryParse('$ratingRaw') ?? 0.0)
          .toDouble(),
      city: userData['city'] ?? tr('il_2491fe94a7'),
      position: userData['position'] ?? 'player',
      friendsSince: friendsSince,
      isOnline: userData['isOnline'] ?? false,
      lastSeen: asDateTimeOrNull(userData['lastSeen']) ??
          asDateTimeOrNull(userData['last_seen_at']),
    );
  }

  // Rating display
  String get ratingDisplay => rating.toStringAsFixed(1);

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
      return tr('il_e345f3fbc6', namedArgs: {'days': '$days'});
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return tr('il_71260c47e0', namedArgs: {'hours': '$hours'});
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return tr('il_031a7ac35e', namedArgs: {'minutes': '$minutes'});
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
