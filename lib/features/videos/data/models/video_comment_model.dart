import '../../domain/entities/video_comment.dart';

class VideoCommentModel {
  static VideoComment fromRow(Map<String, dynamic> row) {
    final profile = _profileMap(row['user_profiles']);
    final name = _displayNameFromProfile(profile, row);
    final avatar = _avatarUrlFromProfile(profile);

    return VideoComment(
      id: row['id']?.toString() ?? '',
      videoId: row['video_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      authorName: name,
      authorAvatarUrl: avatar,
      body: (row['comment_text'] ?? row['body'] ?? '').toString(),
      createdAt: _parse(row['created_at']),
    );
  }

  static Map<String, dynamic>? _profileMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is List && raw.isNotEmpty) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static String _displayNameFromProfile(
    Map<String, dynamic>? p,
    Map<String, dynamic> row,
  ) {
    if (p != null) {
      final dn = p['display_name']?.toString().trim();
      if (dn != null && dn.isNotEmpty) return dn;
      final un = p['username']?.toString().trim();
      if (un != null && un.isNotEmpty) return un;
      final fn = p['first_name']?.toString().trim() ?? '';
      final ln = p['last_name']?.toString().trim() ?? '';
      final combined = [fn, ln].where((s) => s.isNotEmpty).join(' ');
      if (combined.isNotEmpty) return combined;
    }
    final legacy = (row['author_name'] ?? '').toString().trim();
    if (legacy.isNotEmpty) return legacy;
    return 'User';
  }

  static String? _avatarUrlFromProfile(Map<String, dynamic>? p) {
    if (p == null) return null;
    final u = p['avatar_url']?.toString().trim();
    if (u == null || u.isEmpty) return null;
    return u;
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
