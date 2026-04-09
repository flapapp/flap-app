import 'package:flap_app/utils/i18n.dart';

enum FriendRequestStatus {
  pending,
  accepted,
  declined,
  cancelled,
}

class FriendRequest {
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

  FriendRequest({
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

  /// Supabase row (`public.friend_requests`).
  factory FriendRequest.fromSupabaseRow(Map<String, dynamic> row) {
    final statusStr = (row['status'] ?? 'pending').toString();
    return FriendRequest(
      id: row['id']?.toString() ?? '',
      fromUserId: row['from_user_id']?.toString() ?? '',
      fromUserName: row['from_display_name']?.toString() ?? '',
      fromUserAvatar: row['from_avatar_url']?.toString() ?? '',
      toUserId: row['to_user_id']?.toString() ?? '',
      toUserName: row['to_display_name']?.toString() ?? '',
      toUserAvatar: row['to_avatar_url']?.toString() ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => FriendRequestStatus.pending,
      ),
      createdAt: FriendRequest._parseTs(row['created_at']),
      respondedAt:
          row['responded_at'] != null ? FriendRequest._parseTs(row['responded_at']) : null,
      message: row['message']?.toString(),
    );
  }

  static DateTime _parseTs(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }

  /// Parses edge timestamps from Supabase / JSON (same rules as `_parseTs`).
  static DateTime parseRowTimestamp(dynamic v) => _parseTs(v);

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

class Friend {
  final String userId;
  final String name;
  final String avatar;
  final double rating;
  final String city;
  final String position;
  final DateTime friendsSince;
  final bool isOnline;
  final DateTime? lastSeen;

  Friend({
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

  // Factory constructor from user data
  factory Friend.fromUserData(Map<String, dynamic> userData, DateTime friendsSince) {
    return Friend(
      userId: userData['id'] ?? '',
      name: userData['displayName'] ?? userData['name'] ?? userData['email']?.split('@')[0] ?? I18n.inline('Користувач', 'User'),
      avatar: userData['avatarUrl'] ?? userData['avatar'] ?? '', // Спочатку перевіряємо avatarUrl, потім avatar
      rating: (userData['rating'] ?? 0.0).toDouble(),
      city: userData['city'] ?? I18n.inline('Невідоме місто', 'Unknown city'),
      position: userData['position'] ?? 'player',
      friendsSince: friendsSince,
      isOnline: userData['isOnline'] ?? false,
      lastSeen: Friend._parseOptionalDate(userData['lastSeen']),
    );
  }

  /// Supabase `profiles` row + `user_friends.created_at`.
  factory Friend.fromProfileRow({
    required Map<String, dynamic> profile,
    required DateTime friendsSince,
  }) {
    final displayName = (profile['display_name'] ?? '').toString().trim();
    final name = (profile['name'] ?? '').toString().trim();
    final surname = (profile['surname'] ?? '').toString().trim();
    final email = (profile['email'] ?? '').toString();
    final combined = '$name $surname'.trim();
    final label = displayName.isNotEmpty
        ? displayName
        : (combined.isNotEmpty
            ? combined
            : (email.contains('@') ? email.split('@').first : I18n.inline('Користувач', 'User')));
    return Friend(
      userId: profile['id']?.toString() ?? '',
      name: label,
      avatar: (profile['avatar_url'] ?? '').toString(),
      rating: (profile['rating'] as num?)?.toDouble() ?? 0.0,
      city: (profile['city'] ?? '').toString().isNotEmpty
          ? profile['city'].toString()
          : I18n.inline('Невідоме місто', 'Unknown city'),
      position: (profile['position'] ?? 'player').toString(),
      friendsSince: friendsSince,
    );
  }

  static DateTime? _parseOptionalDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
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
        return I18n.inline('🥅 Воротар', '🥅 Goalkeeper');
      case 'defender':
        return I18n.inline('🛡️ Захисник', '🛡️ Defender');
      case 'midfielder':
        return I18n.inline('⚽ Півзахисник', '⚽ Midfielder');
      case 'forward':
        return I18n.inline('🎯 Нападник', '🎯 Forward');
      default:
        return I18n.inline('⚽ Гравець', '⚽ Player');
    }
  }

  // Online status
  String get onlineStatus {
    if (isOnline) return I18n.inline('Онлайн', 'Online');
    
    if (lastSeen == null) return I18n.inline('Давно не був', 'Long time ago');
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen!);
    
    if (difference.inDays > 0) {
      final days = difference.inDays;
      return I18n.inline('Був $days дн. тому', 'Was $days days ago');
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return I18n.inline('Був $hours год. тому', 'Was $hours hours ago');
    } else if (difference.inMinutes > 0) {
      final minutes = difference.inMinutes;
      return I18n.inline('Був $minutes хв. тому', 'Was $minutes minutes ago');
    } else {
      return I18n.inline('Щойно був', 'Just now');
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
