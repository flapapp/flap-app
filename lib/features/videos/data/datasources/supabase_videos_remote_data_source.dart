import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/library_video.dart';
import '../../domain/entities/video_comment.dart';
import '../models/library_video_model.dart';
import '../models/video_comment_model.dart';
import 'videos_remote_data_source.dart';

class SupabaseVideosRemoteDataSource implements VideosRemoteDataSource {
  SupabaseClient get _c => Supabase.instance.client;

  // Keep bucket names aligned with current Supabase schema/policies.
  static const _videoBucket = 'videos';
  static const _challengeVideoBucket = 'challenge_videos';
  static const _thumbBucket = 'thumbnails';

  @override
  Stream<List<LibraryVideo>> watchLibraryVideos({
    String? forUserId,
    int limit = 400,
  }) {
    List<LibraryVideo> mapAndTrim(dynamic raw) {
      final list = (raw as List)
          .map((e) => LibraryVideoModel.fromRow(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) {
          final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      if (list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    }

    if (forUserId != null && forUserId.isNotEmpty) {
      return _c
          .from('videos')
          .stream(primaryKey: ['id'])
          .eq('user_id', forUserId)
          .map(mapAndTrim);
    }
    return _c.from('videos').stream(primaryKey: ['id']).map(mapAndTrim);
  }

  @override
  Stream<LibraryVideo?> watchVideo(String videoId) {
    if (videoId.isEmpty) {
      return Stream<LibraryVideo?>.value(null);
    }
    return _c
        .from('videos')
        .stream(primaryKey: ['id'])
        .eq('id', videoId)
        .map((raw) {
          final list = (raw as List);
          if (list.isEmpty) return null;
          return LibraryVideoModel.fromRow(
            Map<String, dynamic>.from(list.first as Map),
          );
        });
  }

  @override
  Future<LibraryVideo?> fetchVideo(String videoId) async {
    if (videoId.isEmpty) return null;
    final row = await _c.from('videos').select().eq('id', videoId).maybeSingle();
    if (row == null) return null;
    return LibraryVideoModel.fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> incrementViews(String videoId) async {
    if (videoId.isEmpty) return;
    await _c.rpc<void>(
      'increment_video_views',
      params: <String, dynamic>{'p_video_id': videoId},
    );
  }

  @override
  Future<void> setLike({
    required String videoId,
    required String userId,
    required bool liked,
  }) async {
    if (liked) {
      await _c.from('video_likes').insert(<String, dynamic>{
        'video_id': videoId,
        'user_id': userId,
      });
    } else {
      await _c
          .from('video_likes')
          .delete()
          .eq('video_id', videoId)
          .eq('user_id', userId);
    }
  }

  @override
  Stream<bool> watchUserLikesVideo({
    required String videoId,
    required String userId,
  }) {
    return _c
        .from('video_likes')
        .stream(primaryKey: ['video_id', 'user_id'])
        .eq('video_id', videoId)
        .map((raw) {
          final rows = (raw as List).where((e) {
            final m = e as Map;
            return m['user_id']?.toString() == userId;
          }).toList();
          return rows.isNotEmpty;
        });
  }

  @override
  Stream<double> watchLiveAverageVoteRating(String videoId) {
    return _c
        .from('video_votes')
        .stream(primaryKey: ['video_id', 'rated_by'])
        .eq('video_id', videoId)
        .map((raw) {
          final rows = (raw as List).cast<Map>();
          if (rows.isEmpty) return 0.0;
          double sum = 0;
          for (final m in rows) {
            sum += ((m['rating'] ?? 0.0) as num).toDouble();
          }
          final n = rows.length;
          return double.parse((sum / n).toStringAsFixed(2));
        });
  }

  @override
  Future<double> fetchAverageVoteRating(String videoId) async {
    final row = await _c
        .from('videos')
        .select('rating')
        .eq('id', videoId)
        .maybeSingle();
    if (row == null) return 0.0;
    return ((row['rating'] ?? 0.0) as num).toDouble();
  }

  @override
  Future<int> fetchCommentCount(String videoId) async {
    final row = await _c
        .from('videos')
        .select('comments_count')
        .eq('id', videoId)
        .maybeSingle();
    if (row == null) return 0;
    return (row['comments_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<bool> userHasVote({
    required String videoId,
    required String userId,
  }) async {
    final row = await _c
        .from('video_votes')
        .select('rated_by')
        .eq('video_id', videoId)
        .eq('rated_by', userId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<Map<String, double>?> fetchUserVoteCriteria({
    required String videoId,
    required String userId,
  }) async {
    final row = await _c
        .from('video_votes')
        .select('criteria')
        .eq('video_id', videoId)
        .eq('rated_by', userId)
        .maybeSingle();
    if (row == null) return null;
    final c = row['criteria'];
    if (c is! Map) return null;
    final out = <String, double>{};
    for (final e in c.entries) {
      final v = e.value;
      if (v is num) out[e.key.toString()] = v.toDouble();
    }
    return out;
  }

  @override
  Future<List<VideoComment>> fetchComments(String videoId) async {
    final rows = await _c
        .from('video_comments')
        .select()
        .eq('video_id', videoId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => VideoCommentModel.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Stream<List<VideoComment>> watchComments(String videoId) {
    return _c
        .from('video_comments')
        .stream(primaryKey: ['id'])
        .eq('video_id', videoId)
        .map((raw) {
          final rows = (raw as List)
              .map((e) => VideoCommentModel.fromRow(Map<String, dynamic>.from(e as Map)))
              .toList()
            ..sort((a, b) {
              final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
              final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
              return bt.compareTo(at);
            });
          return rows;
        });
  }

  @override
  Future<void> addComment({
    required String videoId,
    required String userId,
    required String authorName,
    required String body,
  }) async {
    await _c.from('video_comments').insert(<String, dynamic>{
      'video_id': videoId,
      'user_id': userId,
      'author_name': authorName,
      'body': body,
    });
  }

  @override
  Future<String> insertVideoRow(Map<String, dynamic> row) async {
    final res = await _c.from('videos').insert(row).select('id').single();
    return res['id'].toString();
  }

  @override
  Future<void> updateVideoThumbnail({
    required String videoId,
    required String thumbnailUrl,
    String? thumbnailStoragePath,
    bool thumbnailGenerated = true,
    String? thumbnailType,
  }) async {
    await _c.from('videos').update(<String, dynamic>{
      'thumbnail_url': thumbnailUrl,
      if (thumbnailStoragePath != null) 'thumbnail_storage_path': thumbnailStoragePath,
      'thumbnail_generated': thumbnailGenerated,
      if (thumbnailType != null) 'thumbnail_type': thumbnailType,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', videoId);
  }

  @override
  Future<void> updateVideoFields(
    String videoId,
    Map<String, dynamic> patch,
  ) async {
    if (patch.isEmpty) return;
    final p = Map<String, dynamic>.from(patch);
    p['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _c.from('videos').update(p).eq('id', videoId);
  }

  @override
  Future<({String publicUrl, String path})> uploadVideoBytes({
    required String userId,
    required List<int> bytes,
    required String fileName,
    bool isChallengeVideo = false,
  }) async {
    final path = '$userId/$fileName';
    final bytesData = Uint8List.fromList(bytes);
    final preferredBucket = isChallengeVideo ? _challengeVideoBucket : _videoBucket;

    Future<bool> _isRetriableError(Object e) async {
      if (e is! StorageException) return false;
      final status = e.statusCode?.toString() ?? '';
      final msg = (e.message).toLowerCase();
      return status == '502' ||
          status == '503' ||
          status == '504' ||
          msg.contains('bad gateway') ||
          msg.contains('timeout') ||
          msg.contains('temporar');
    }

    Future<({String publicUrl, String path})> _uploadToBucket(String bucket) async {
      const backoffMs = <int>[0, 500, 1500];
      Object? lastError;
      for (final ms in backoffMs) {
        if (ms > 0) {
          await Future<void>.delayed(Duration(milliseconds: ms));
        }
        try {
          await _c.storage.from(bucket).uploadBinary(
                path,
                bytesData,
                fileOptions: const FileOptions(
                  contentType: 'video/mp4',
                  upsert: true,
                ),
              );
          final url = _c.storage.from(bucket).getPublicUrl(path);
          return (publicUrl: url, path: path);
        } catch (e) {
          lastError = e;
          if (!await _isRetriableError(e)) rethrow;
        }
      }
      throw lastError ?? Exception('Video upload failed after retries');
    }

    return _uploadToBucket(preferredBucket);
  }

  @override
  Future<({String publicUrl, String path})> uploadThumbnailBytes({
    required String userId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final path = '$userId/$fileName';
    await _c.storage.from(_thumbBucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final url = _c.storage.from(_thumbBucket).getPublicUrl(path);
    return (publicUrl: url, path: path);
  }

  @override
  Future<void> deleteVideoAndFilesIfOwner({
    required String videoId,
    required String userId,
  }) async {
    final row = await _c
        .from('videos')
        .select('user_id, video_storage_path, thumbnail_storage_path')
        .eq('id', videoId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return;

    final vPath = row['video_storage_path']?.toString();
    final tPath = row['thumbnail_storage_path']?.toString();
    if (vPath != null && vPath.isNotEmpty) {
      try {
        await _c.storage.from(_videoBucket).remove([vPath]);
      } catch (_) {}
    }
    if (tPath != null && tPath.isNotEmpty) {
      try {
        await _c.storage.from(_thumbBucket).remove([tPath]);
      } catch (_) {}
    }

    await _c.from('videos').delete().eq('id', videoId).eq('user_id', userId);
  }

  @override
  Future<String?> findLibraryVideoIdByUrl({
    required String userId,
    required String videoUrl,
  }) async {
    final rows = await _c
        .from('videos')
        .select('id')
        .eq('user_id', userId)
        .eq('video_url', videoUrl)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return (list.first as Map)['id']?.toString();
  }

  @override
  Future<List<LibraryVideo>> fetchUserVideosByViews({
    required String userId,
    int limit = 50,
  }) async {
    final rows = await _c
        .from('videos')
        .select()
        .eq('user_id', userId)
        .order('views', ascending: false)
        .limit(limit);
    final list = (rows as List)
        .map((e) => LibraryVideoModel.fromRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    return list;
  }

  @override
  Future<void> insertVideoVote({
    required String videoId,
    required String ratedBy,
    required double rating,
    required Map<String, dynamic> criteria,
  }) async {
    await _c.from('video_votes').insert(<String, dynamic>{
      'video_id': videoId,
      'rated_by': ratedBy,
      'rating': rating,
      'criteria': criteria,
      'rated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
