import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps a Supabase `profiles` row to the legacy Firestore `users` document shape
/// consumed by profile UI.
Map<String, dynamic> profileRowToLegacyUserMap(Map<String, dynamic> row) {
  final settingsRaw = row['settings'];
  final settingsMap = settingsRaw is Map
      ? Map<String, dynamic>.from(settingsRaw)
      : <String, dynamic>{};

  final id = row['id']?.toString() ?? '';
  final displayName = row['display_name']?.toString();
  final name = row['name']?.toString();

  final ratingHistRaw = row['rating_history'];
  final ratingHistory = <Map<String, dynamic>>[];
  if (ratingHistRaw is List) {
    for (final e in ratingHistRaw) {
      if (e is Map) {
        ratingHistory.add(Map<String, dynamic>.from(e));
      }
    }
  }

  final totalMatches =
      (row['total_matches'] ?? row['matches'] ?? 0) as num? ?? 0;
  final totalVideos = (row['total_videos'] ?? 0) as num? ?? 0;

  return <String, dynamic>{
    'uid': id,
    'id': id,
    'displayName': displayName ?? name,
    'authorName': displayName ?? name,
    'name': name,
    'surname': row['surname'],
    'email': row['email'],
    'phone': row['phone'],
    'city': row['city'],
    'age': row['age'],
    'position': row['position'],
    'experience': row['experience'],
    'rating': row['rating'] ?? 0.0,
    'matchRating': row['match_rating'],
    'videoRating': row['video_rating'],
    'coins': row['coins'] ?? 0,
    'flCoins': row['coins'] ?? 0,
    'avatar': row['avatar_url'],
    'avatarUrl': row['avatar_url'],
    'photoUrl': row['avatar_url'],
    'totalMatches': totalMatches,
    'matches': totalMatches,
    'matchesPlayed': totalMatches,
    'totalVideos': totalVideos,
    'videosUploaded': totalVideos,
    'wins': row['wins'] ?? 0,
    'losses': row['losses'] ?? 0,
    'draws': row['draws'] ?? 0,
    'wonMatches': row['wins'] ?? 0,
    'lostMatches': row['losses'] ?? 0,
    'drawMatches': row['draws'] ?? 0,
    'goals': row['goals'] ?? 0,
    'assists': row['assists'] ?? 0,
    'averageRating': row['rating'] ?? 0.0,
    'ratingHistory': ratingHistory,
    'settings': settingsMap,
  };
}

/// Parses [ratingHistory] entries from Supabase (ISO strings) or Firestore legacy.
DateTime? profileRatingHistoryTimestamp(dynamic ts) {
  if (ts is Timestamp) return ts.toDate();
  if (ts is String) {
    return DateTime.tryParse(ts)?.toLocal();
  }
  return null;
}
