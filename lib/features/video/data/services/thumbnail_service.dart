import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_app_storage.dart';
import 'web_thumbnail_service.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  SupabaseClient get _sb => Supabase.instance.client;

  /// Generates a video thumbnail and uploads it to Firebase Storage
  Future<String?> generateAndUploadThumbnail({
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('[thumb] Starting thumbnail generation for video: $videoId');
      
      if (kIsWeb) {
        // On web, use WebThumbnailService
        final webService = WebThumbnailService();
        return await webService.generateWebThumbnail(
          videoUrl: videoUrl,
          videoId: videoId,
          userId: userId,
        );
      }
      
      // On mobile, use video_thumbnail
      final thumbnailData = await _generateThumbnail(videoUrl);
      if (thumbnailData == null) {
        print('[thumb] ERROR: Failed to generate thumbnail data');
        return null;
      }

      print('[thumb] Thumbnail generated, size: ${thumbnailData.length} bytes');

      // Upload thumbnail to Firebase Storage
      final thumbnailUrl = await _uploadThumbnail(
        thumbnailData: thumbnailData,
        videoId: videoId,
        userId: userId,
      );

      if (thumbnailUrl != null) {
        // Update video document with thumbnail URL
        await _updateVideoThumbnail(videoId, thumbnailUrl);
        print('[thumb] Thumbnail uploaded and video updated: $thumbnailUrl');
      }

      return thumbnailUrl;
    } catch (e) {
      print('[thumb] ERROR in generateAndUploadThumbnail: $e');
      return null;
    }
  }

  /// Generates a thumbnail from a video URL
  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      if (kIsWeb) {
        // video_thumbnail is not supported on web
        // Use a stub or alternate approach
        print('[thumb] WARN: Web platform thumbnail generation not supported, using placeholder');
        return null;
      }

      // Generate thumbnail
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720, // Higher quality for clearer preview
        quality: 85,
        timeMs: 1000, // Sample frame at 1s
      );

      return thumbnailData;
    } catch (e) {
      print('[thumb] ERROR generating thumbnail: $e');
      return null;
    }
  }

  /// Uploads thumbnail to Firebase Storage
  Future<String?> _uploadThumbnail({
    required Uint8List thumbnailData,
    required String videoId,
    required String userId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'thumbnail_${videoId}_$timestamp.jpg';
      final objectPath = '$userId/$fileName';

      print('[thumb] Uploading thumbnail: $objectPath');

      final downloadUrl = await SupabaseAppStorage.uploadPublicBytes(
        _sb,
        bucket: SupabaseAppStorage.thumbnails,
        path: objectPath,
        bytes: thumbnailData,
        contentType: 'image/jpeg',
      );
      
      print('[thumb] Thumbnail uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('[thumb] ERROR uploading thumbnail: $e');
      return null;
    }
  }

  /// Updates the video document with the thumbnail URL
  Future<void> _updateVideoThumbnail(String videoId, String thumbnailUrl) async {
    try {
      await _sb.from('videos').update(<String, dynamic>{
        'thumbnail_url': thumbnailUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', videoId);

      print('[thumb] Video document updated with thumbnail URL');
    } catch (e) {
      print('[thumb] ERROR updating video with thumbnail: $e');
    }
  }

  /// Generates thumbnail for challenge creator video
  Future<String?> generateChallengeThumbnail({
    required String videoUrl,
    required String challengeId,
    required String userId,
  }) async {
    try {
      print('[thumb] Generating challenge thumbnail for: $challengeId');
      
      if (kIsWeb) {
        // On web, use WebThumbnailService
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
      final objectPath = '$userId/$fileName';

      final downloadUrl = await SupabaseAppStorage.uploadPublicBytes(
        _sb,
        bucket: SupabaseAppStorage.challengeThumbnails,
        path: objectPath,
        bytes: thumbnailData,
        contentType: 'image/jpeg',
      );

      // Update challenge with thumbnail
      await _sb.from('challenges').update(<String, dynamic>{
        'image_url': downloadUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', challengeId);

      print('[thumb] Challenge thumbnail generated: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('[thumb] ERROR generating challenge thumbnail: $e');
      return null;
    }
  }

  /// Generates thumbnail for a challenge submission video
  Future<String?> generateSubmissionThumbnail({
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
      final objectPath = '$userId/$challengeId/$fileName';

      final downloadUrl = await SupabaseAppStorage.uploadPublicBytes(
        _sb,
        bucket: SupabaseAppStorage.submissionThumbnails,
        path: objectPath,
        bytes: thumbnailData,
        contentType: 'image/jpeg',
      );

      // Update submission with thumbnail
      await _sb.from('challenge_submissions').update(<String, dynamic>{
        'thumbnail_url': downloadUrl,
      }).eq('id', submissionId);

      print('[thumb] Submission thumbnail generated: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('[thumb] ERROR generating submission thumbnail: $e');
      return null;
    }
  }

  /// Whether a thumbnail should be generated for the video
  Future<bool> needsThumbnail(String videoId) async {
    try {
      final row =
          await _sb.from('videos').select('thumbnail_url').eq('id', videoId).maybeSingle();
      if (row == null) return false;
      final thumbnailUrl = row['thumbnail_url'] as String?;

      // Need thumbnail when missing or not generated
      return thumbnailUrl == null || thumbnailUrl.isEmpty;
    } catch (e) {
      print('Error checking thumbnail status: $e');
      return true; // On error, prefer generating
    }
  }

  /// Batch-generate thumbnails for existing videos
  Future<void> generateMissingThumbnails() async {
    try {
      print('[thumb] Starting bulk thumbnail generation...');
      
      // Fetch videos missing thumbnails
      final videosQuery = await _sb
          .from('videos')
          .select('id,video_url,user_id,thumbnail_url')
          .isFilter('thumbnail_url', null)
          .limit(10) // Process 10 at a time
          ;

      final rows = videosQuery as List<dynamic>;
      print('[thumb] Found ${rows.length} videos without thumbnails');

      for (final doc in rows) {
        final data = doc as Map<String, dynamic>;
        final videoUrl = data['video_url'] as String?;
        final userId = data['user_id'] as String?;
        
        if (videoUrl != null && userId != null) {
          await generateAndUploadThumbnail(
            videoUrl: videoUrl,
            videoId: (data['id'] ?? '').toString(),
            userId: userId,
          );
          
          // Small delay between generations
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      print('[thumb] Bulk thumbnail generation completed');
    } catch (e) {
      print('[thumb] ERROR in bulk thumbnail generation: $e');
    }
  }
}
