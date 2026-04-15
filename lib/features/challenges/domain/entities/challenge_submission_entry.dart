/// One row in `public.challenge_submissions` for a challenge.
class ChallengeSubmissionEntry {
  const ChallengeSubmissionEntry({
    required this.userId,
    required this.videoId,
    required this.videoUrl,
    required this.title,
    required this.authorName,
    required this.createdAt,
    required this.averageRating,
    required this.voteCount,
    required this.thumbnailUrl,
    required this.isCreatorVideo,
  });

  final String userId;
  final String videoId;
  final String videoUrl;
  final String title;
  final String authorName;
  final DateTime createdAt;
  final double averageRating;
  final int voteCount;
  final String thumbnailUrl;
  final bool isCreatorVideo;

  factory ChallengeSubmissionEntry.fromSupabaseRow(Map<String, dynamic> row) {
    final createdAt = ChallengeSubmissionEntry._ts(row['created_at']);
    return ChallengeSubmissionEntry(
      userId: row['user_id']?.toString() ?? '',
      videoId: row['video_storage_path']?.toString() ?? '',
      videoUrl: row['video_url']?.toString() ?? '',
      title: row['title']?.toString() ?? '',
      authorName:
          row['author_name']?.toString() ??
          row['user_profiles']?['display_name']?.toString() ??
          row['user_profiles']?['username']?.toString() ??
          '',
      createdAt: createdAt,
      averageRating: (row['average_rating'] as num?)?.toDouble() ?? 0.0,
      voteCount: (row['vote_count'] as num?)?.toInt() ?? 0,
      thumbnailUrl: row['thumbnail_url']?.toString() ?? '',
      isCreatorVideo: row['is_creator_video'] as bool? ?? false,
    );
  }

  static DateTime _ts(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }
}
