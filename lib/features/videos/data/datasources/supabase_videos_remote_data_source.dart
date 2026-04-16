import 'dart:async';
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

  static int _starIntFromDouble(double v) => v.round().clamp(1, 5);

  static const _videoAuthorProfileSelect =
      'user_profiles(display_name, username, first_name, last_name)';

  /// Realtime `videos` rows omit joins; merge `user_profiles` so [LibraryVideo.authorName] resolves.
  Future<List<Map<String, dynamic>>> _mergeUserProfilesForVideoRows(
    List<Map<String, dynamic>> maps,
  ) async {
    if (maps.isEmpty) return maps;

    var work = List<Map<String, dynamic>>.from(maps);
    final needsFetch = work.any(
      (m) =>
          m['user_profiles'] == null &&
          (m['user_id']?.toString().isNotEmpty ?? false),
    );
    if (!needsFetch) return work;

    final ids = work
        .map((m) => m['user_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return work;

    final profs = await _c
        .from('user_profiles')
        .select('id, display_name, username, first_name, last_name')
        .inFilter('id', ids);
    final byId = <String, Map<String, dynamic>>{};
    for (final p in (profs as List)) {
      final m = Map<String, dynamic>.from(p as Map);
      byId[m['id']!.toString()] = m;
    }
    work = work.map((row) {
      final uid = row['user_id']?.toString();
      if (uid == null) return row;
      final p = byId[uid];
      if (p == null) return row;
      return <String, dynamic>{...row, 'user_profiles': p};
    }).toList();
    return work;
  }

  @override
  Stream<List<LibraryVideo>> watchLibraryVideos({
    String? forUserId,
    int limit = 400,
  }) {
    Future<List<LibraryVideo>> mapTrimAndEnrich(dynamic raw) async {
      final maps =
          (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final merged = await _mergeUserProfilesForVideoRows(maps);
      final list = merged
          .map(LibraryVideoModel.fromRow)
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

    final stream = forUserId != null && forUserId.isNotEmpty
        ? _c.from('videos').stream(primaryKey: ['id']).eq('user_id', forUserId)
        : _c.from('videos').stream(primaryKey: ['id']);
    return stream.asyncMap(mapTrimAndEnrich);
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
        .asyncMap((raw) async {
          final list = raw as List;
          if (list.isEmpty) return null;
          final maps = [Map<String, dynamic>.from(list.first as Map)];
          final merged = await _mergeUserProfilesForVideoRows(maps);
          if (merged.isEmpty) return null;
          return LibraryVideoModel.fromRow(merged.first);
        });
  }

  @override
  Future<LibraryVideo?> fetchVideo(String videoId) async {
    if (videoId.isEmpty) return null;
    final row = await _c
        .from('videos')
        .select('*, $_videoAuthorProfileSelect')
        .eq('id', videoId)
        .maybeSingle();
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
        .from('video_ratings')
        .stream(primaryKey: ['id'])
        .eq('video_id', videoId)
        .map((raw) {
          final rows = (raw as List).cast<Map>();
          if (rows.isEmpty) return 0.0;
          double sum = 0;
          for (final m in rows) {
            sum += ((m['overall_rating'] ?? 0) as num).toDouble();
          }
          final n = rows.length;
          return double.parse((sum / n).toStringAsFixed(2));
        });
  }

  @override
  Future<double> fetchAverageVoteRating(String videoId) async {
    final row = await _c
        .from('video_rating_aggregates')
        .select('avg_overall_rating')
        .eq('video_id', videoId)
        .maybeSingle();
    if (row == null) return 0.0;
    return ((row['avg_overall_rating'] ?? 0.0) as num).toDouble();
  }

  @override
  Future<int> fetchCommentCount(String videoId) async {
    final row = await _c
        .from('videos')
        .select('comment_count')
        .eq('id', videoId)
        .maybeSingle();
    if (row == null) return 0;
    return (row['comment_count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<bool> userHasVote({
    required String videoId,
    required String userId,
  }) async {
    final row = await _c
        .from('video_ratings')
        .select('user_id')
        .eq('video_id', videoId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  @override
  Future<Map<String, double>?> fetchUserVoteCriteria({
    required String videoId,
    required String userId,
  }) async {
    final row = await _c
        .from('video_ratings')
        .select(
          'technical_rating, creativity_rating, difficulty_rating, video_quality_rating',
        )
        .eq('video_id', videoId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    double? n(String k) {
      final v = row[k];
      if (v is num) return v.toDouble();
      return null;
    }

    final technical = n('technical_rating');
    final creativity = n('creativity_rating');
    final difficulty = n('difficulty_rating');
    final quality = n('video_quality_rating');
    if (technical == null &&
        creativity == null &&
        difficulty == null &&
        quality == null) {
      return null;
    }
    return <String, double>{
      if (technical != null) 'technical': technical,
      if (creativity != null) 'creativity': creativity,
      if (difficulty != null) 'difficulty': difficulty,
      if (quality != null) 'quality': quality,
    };
  }

  static const _commentProfileSelect =
      'user_profiles(display_name, username, avatar_url, first_name, last_name)';

  Future<List<VideoComment>> _commentMapsToModels(
    List<Map<String, dynamic>> maps,
  ) async {
    if (maps.isEmpty) return [];

    var work = List<Map<String, dynamic>>.from(maps);

    final needsFetch = work.any(
      (m) =>
          m['user_profiles'] == null &&
          (m['user_id']?.toString().isNotEmpty ?? false),
    );
    if (needsFetch) {
      final ids = work
          .map((m) => m['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      if (ids.isNotEmpty) {
        final profs = await _c
            .from('user_profiles')
            .select(
              'id, display_name, username, avatar_url, first_name, last_name',
            )
            .inFilter('id', ids);
        final byId = <String, Map<String, dynamic>>{};
        for (final p in (profs as List)) {
          final m = Map<String, dynamic>.from(p as Map);
          byId[m['id']!.toString()] = m;
        }
        work = work.map((row) {
          final uid = row['user_id']?.toString();
          if (uid == null) return row;
          final p = byId[uid];
          if (p == null) return row;
          return <String, dynamic>{...row, 'user_profiles': p};
        }).toList();
      }
    }

    return work.map(VideoCommentModel.fromRow).toList();
  }

  @override
  Future<List<VideoComment>> fetchComments(String videoId) async {
    final rows = await _c
        .from('video_comments')
        .select(
          'id, video_id, user_id, comment_text, created_at, updated_at, deleted_at, $_commentProfileSelect',
        )
        .eq('video_id', videoId)
        .order('created_at', ascending: false);
    final maps =
        (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return _commentMapsToModels(maps);
  }

  @override
  Stream<List<VideoComment>> watchComments(String videoId) {
    return _c
        .from('video_comments')
        .stream(primaryKey: ['id'])
        .eq('video_id', videoId)
        .asyncMap((raw) async {
          var maps = (raw as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final list = await _commentMapsToModels(maps);
          list.sort((a, b) {
            final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });
          return list;
        });
  }

  @override
  Future<void> addComment({
    required String videoId,
    required String userId,
    required String authorName,
    required String body,
  }) async {
    final t = body.trim().isEmpty ? '-' : body.trim();
    await _c.from('video_comments').insert(<String, dynamic>{
      'video_id': videoId,
      'user_id': userId,
      'comment_text': t,
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
      try {
        await _c.storage.from(_challengeVideoBucket).remove([vPath]);
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
        .select('*, $_videoAuthorProfileSelect')
        .eq('user_id', userId)
        .order('view_count', ascending: false)
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
    num? crit(String k) {
      final v = criteria[k];
      if (v is num) return v;
      return null;
    }

    final row = <String, dynamic>{
      'video_id': videoId,
      'user_id': ratedBy,
      'overall_rating': _starIntFromDouble(rating),
      if (crit('technical') != null)
        'technical_rating': _starIntFromDouble(crit('technical')!.toDouble()),
      if (crit('creativity') != null)
        'creativity_rating': _starIntFromDouble(crit('creativity')!.toDouble()),
      if (crit('difficulty') != null)
        'difficulty_rating': _starIntFromDouble(crit('difficulty')!.toDouble()),
      if (crit('quality') != null)
        'video_quality_rating': _starIntFromDouble(crit('quality')!.toDouble()),
    };

    await _c.from('video_ratings').upsert(
          row,
          onConflict: 'video_id,user_id',
        );
  }
}
