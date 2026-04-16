/// Maps a Supabase `user_profiles` row to the legacy Firestore `users` document shape
/// consumed by profile UI.
Map<String, dynamic> profileRowToLegacyUserMap(Map<String, dynamic> row) {
  final settingsRaw = row['settings'];
  final settingsMap = settingsRaw is Map
      ? Map<String, dynamic>.from(settingsRaw)
      : <String, dynamic>{};

  final id = row['id']?.toString() ?? '';
  final fn = row['first_name']?.toString().trim();
  final ln = row['last_name']?.toString().trim();
  final displayName = row['display_name']?.toString();
  final username = row['username']?.toString().trim();
  final name = row['name']?.toString() ?? (fn ?? '');
  final surname = row['surname']?.toString() ?? (ln ?? '');

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

  final combined = _combinedFirstLast(fn, ln);
  var resolvedDisplay = (displayName != null && displayName.trim().isNotEmpty)
      ? displayName.trim()
      : (combined.isNotEmpty ? combined : name);
  if (resolvedDisplay.isEmpty &&
      username != null &&
      username.isNotEmpty) {
    resolvedDisplay = username;
  }

  return <String, dynamic>{
    'uid': id,
    'id': id,
    'displayName': resolvedDisplay,
    'authorName': resolvedDisplay,
    'name': name,
    'surname': surname,
    'email': row['email'],
    'phone': row['phone'],
    'city': row['city'],
    'age': row['age'] ??
        (row['date_of_birth'] != null
            ? _ageFromDob(row['date_of_birth'])
            : null),
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

String _combinedFirstLast(String? a, String? b) {
  final p = <String>[];
  if (a != null && a.isNotEmpty) p.add(a);
  if (b != null && b.isNotEmpty) p.add(b);
  return p.join(' ');
}

int? _ageFromDob(dynamic raw) {
  if (raw == null) return null;
  final dt = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
  if (dt == null) return null;
  final now = DateTime.now();
  var age = now.year - dt.year;
  if (now.month < dt.month ||
      (now.month == dt.month && now.day < dt.day)) {
    age--;
  }
  return age < 0 ? 0 : age;
}

/// Parses [ratingHistory] entries from Supabase (ISO strings).
DateTime? profileRatingHistoryTimestamp(dynamic ts) {
  if (ts is String) {
    return DateTime.tryParse(ts)?.toLocal();
  }
  if (ts is DateTime) return ts;
  return null;
}
