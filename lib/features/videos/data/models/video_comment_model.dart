import '../../domain/entities/video_comment.dart';

class VideoCommentModel {
  static VideoComment fromRow(Map<String, dynamic> row) {
    return VideoComment(
      id: row['id']?.toString() ?? '',
      videoId: row['video_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      authorName: (row['author_name'] ?? '').toString(),
      body: (row['body'] ?? '').toString(),
      createdAt: _parse(row['created_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
