import '../../domain/entities/library_video.dart';

class LibraryVideoModel {
  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static LibraryVideo fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final userId = row['user_id']?.toString() ?? '';
    final challengeId = row['challenge_id']?.toString();
    final isChallenge = row['is_challenge_video'] == true ||
        (challengeId != null && challengeId.isNotEmpty);

    return LibraryVideo(
      id: id,
      userId: userId,
      authorName: _authorFromRow(row),
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      category: (row['category'] ?? '').toString(),
      difficulty: row['difficulty']?.toString(),
      videoUrl: (row['video_url'] ?? '').toString(),
      videoStoragePath: row['video_storage_path']?.toString(),
      thumbnailUrl: row['thumbnail_url']?.toString(),
      thumbnailStoragePath: row['thumbnail_storage_path']?.toString(),
      thumbnailGenerated: row['thumbnail_generated'] == true,
      thumbnailType: row['thumbnail_type']?.toString(),
      likes: (row['likes'] as num?)?.toInt() ?? 0,
      rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
      voteCount: (row['vote_count'] as num?)?.toInt() ?? 0,
      views: (row['views'] as num?)?.toInt() ?? 0,
      commentsCount: (row['comments_count'] as num?)?.toInt() ?? 0,
      city: row['city']?.toString(),
      challengeId: challengeId,
      challengeTitle: row['challenge_title']?.toString(),
      isChallengeVideo: isChallenge,
      createdAt: _parseTs(row['created_at']),
    );
  }

  /// Prefer embedded `user_profiles` from PostgREST; no `videos.author_name` column.
  static String _authorFromRow(Map<String, dynamic> row) {
    dynamic up = row['user_profiles'];
    if (up is List && up.isNotEmpty) {
      up = up.first;
    }
    if (up is Map) {
      final v = up['display_name'] ?? up['username'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString();
      }
    }
    return '';
  }
}
