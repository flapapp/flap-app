import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';
import 'web_thumbnail_service.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  static const _thumbBucket = 'thumbnails';

  /// Генерує thumbnail для відео та зберігає його в Supabase Storage
  Future<String?> generateAndUploadThumbnail({
    required VideosRepository videosRepository,
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('🎬 Starting thumbnail generation for video: $videoId');

      if (kIsWeb) {
        final webService = WebThumbnailService();
        return await webService.generateWebThumbnail(
          videosRepository: videosRepository,
          videoUrl: videoUrl,
          videoId: videoId,
          userId: userId,
        );
      }

      final thumbnailData = await _generateThumbnail(videoUrl);
      if (thumbnailData == null) {
        print('❌ Failed to generate thumbnail data');
        return null;
      }

      print('✅ Thumbnail generated, size: ${thumbnailData.length} bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'thumbnail_${videoId}_$timestamp.jpg';
      final uploaded = await videosRepository.uploadThumbnailBytes(
        userId: userId,
        bytes: thumbnailData,
        fileName: fileName,
      );

      await videosRepository.updateVideoThumbnail(
        videoId: videoId,
        thumbnailUrl: uploaded.publicUrl,
        thumbnailStoragePath: uploaded.path,
        thumbnailGenerated: true,
      );

      print('✅ Thumbnail uploaded and video updated: ${uploaded.publicUrl}');
      return uploaded.publicUrl;
    } catch (e) {
      print('❌ Error in generateAndUploadThumbnail: $e');
      return null;
    }
  }

  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      if (kIsWeb) {
        print('⚠️ Web platform: thumbnail generation not supported, using placeholder');
        return null;
      }

      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720,
        quality: 85,
        timeMs: 1000,
      );

      return thumbnailData;
    } catch (e) {
      print('❌ Error generating thumbnail: $e');
      return null;
    }
  }

  /// Генерує thumbnail для челенджу (відео творця)
  Future<String?> generateChallengeThumbnail({
    required String videoUrl,
    required String challengeId,
    required String userId,
  }) async {
    try {
      print('🏆 Generating challenge thumbnail for: $challengeId');

      if (kIsWeb) {
        final webService = WebThumbnailService();
        return await webService.generateWebChallengeThumbnail(
          videoUrl: videoUrl,
          challengeId: challengeId,
          userId: userId,
        );
      }

      final thumbnailData = await _generateThumbnail(videoUrl);
      if (thumbnailData == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'challenge_thumb_${challengeId}_$timestamp.jpg';
      final path = '$userId/$fileName';
      await _client.storage.from(_thumbBucket).uploadBinary(
            path,
            thumbnailData,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      final downloadUrl = _client.storage.from(_thumbBucket).getPublicUrl(path);

      await _client.rpc<void>(
        'challenge_set_creator_video',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_creator_video_url': '',
          'p_creator_thumbnail_url': downloadUrl,
        },
      );

      print('✅ Challenge thumbnail generated: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error generating challenge thumbnail: $e');
      return null;
    }
  }

  /// Генерує thumbnail для відео учасника челенджу
  Future<String?> generateSubmissionThumbnail({
    required VideosRepository videosRepository,
    required String videoUrl,
    required String challengeId,
    required String submissionId,
    required String userId,
  }) async {
    try {
      final thumbnailData = await _generateThumbnail(videoUrl);
      if (thumbnailData == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'submission_thumb_${submissionId}_$timestamp.jpg';
      final uploaded = await videosRepository.uploadThumbnailBytes(
        userId: userId,
        bytes: thumbnailData,
        fileName: fileName,
      );

      await _client.rpc<void>(
        'challenge_submission_set_thumbnail',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_user_id': userId,
          'p_thumbnail_url': uploaded.publicUrl,
        },
      );

      print('✅ Submission thumbnail generated: ${uploaded.publicUrl}');
      return uploaded.publicUrl;
    } catch (e) {
      print('❌ Error generating submission thumbnail: $e');
      return null;
    }
  }

  Future<bool> needsThumbnail({
    required VideosRepository videosRepository,
    required String videoId,
  }) async {
    try {
      final v = await videosRepository.fetchVideo(videoId);
      if (v == null) return false;
      final thumbnailUrl = v.thumbnailUrl;
      if (thumbnailUrl == null || thumbnailUrl.isEmpty) return true;
      return !v.thumbnailGenerated;
    } catch (e) {
      print('Error checking thumbnail status: $e');
      return true;
    }
  }

  Future<void> generateMissingThumbnails({
    required VideosRepository videosRepository,
  }) async {
    try {
      print('🔄 Starting bulk thumbnail generation...');

      final rows = await _client
          .from('videos')
          .select('id, user_id, video_url, thumbnail_generated, thumbnail_url')
          .eq('thumbnail_generated', false)
          .limit(10);

      final list = (rows as List).cast<Map>();
      print('📊 Found ${list.length} videos without thumbnails');

      for (final row in list) {
        final id = row['id']?.toString();
        final videoUrl = row['video_url']?.toString();
        final userId = row['user_id']?.toString();
        if (id != null &&
            videoUrl != null &&
            userId != null &&
            id.isNotEmpty &&
            videoUrl.isNotEmpty &&
            userId.isNotEmpty) {
          await generateAndUploadThumbnail(
            videosRepository: videosRepository,
            videoUrl: videoUrl,
            videoId: id,
            userId: userId,
          );
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      print('✅ Bulk thumbnail generation completed');
    } catch (e) {
      print('❌ Error in bulk thumbnail generation: $e');
    }
  }
}
