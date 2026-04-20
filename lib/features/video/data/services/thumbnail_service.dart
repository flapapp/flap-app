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

  /// Генерує thumbnail для відео та зберігає його в Firebase Storage
  Future<String?> generateAndUploadThumbnail({
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('🎬 Starting thumbnail generation for video: $videoId');
      
      if (kIsWeb) {
        // На веб-платформі використовуємо WebThumbnailService
        final webService = WebThumbnailService();
        return await webService.generateWebThumbnail(
          videoUrl: videoUrl,
          videoId: videoId,
          userId: userId,
        );
      }
      
      // На мобільних платформах використовуємо video_thumbnail
      final thumbnailData = await _generateThumbnail(videoUrl);
      if (thumbnailData == null) {
        print('❌ Failed to generate thumbnail data');
        return null;
      }

      print('✅ Thumbnail generated, size: ${thumbnailData.length} bytes');

      // Завантажуємо thumbnail в Firebase Storage
      final thumbnailUrl = await _uploadThumbnail(
        thumbnailData: thumbnailData,
        videoId: videoId,
        userId: userId,
      );

      if (thumbnailUrl != null) {
        // Оновлюємо документ відео з URL thumbnail
        await _updateVideoThumbnail(videoId, thumbnailUrl);
        print('✅ Thumbnail uploaded and video updated: $thumbnailUrl');
      }

      return thumbnailUrl;
    } catch (e) {
      print('❌ Error in generateAndUploadThumbnail: $e');
      return null;
    }
  }

  /// Генерує thumbnail з відео URL
  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    try {
      if (kIsWeb) {
        // На веб-платформі video_thumbnail не підтримується
        // Використовуємо заглушку або інший підхід
        print('⚠️ Web platform: thumbnail generation not supported, using placeholder');
        return null;
      }

      // Генеруємо thumbnail
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720, // Висока якість для гарного превью
        quality: 85,
        timeMs: 1000, // Беремо кадр з 1-ї секунди
      );

      return thumbnailData;
    } catch (e) {
      print('❌ Error generating thumbnail: $e');
      return null;
    }
  }

  /// Завантажує thumbnail в Firebase Storage
  Future<String?> _uploadThumbnail({
    required Uint8List thumbnailData,
    required String videoId,
    required String userId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'thumbnail_${videoId}_$timestamp.jpg';
      final objectPath = '$userId/$fileName';

      print('📤 Uploading thumbnail: $objectPath');

      final downloadUrl = await SupabaseAppStorage.uploadPublicBytes(
        _sb,
        bucket: SupabaseAppStorage.thumbnails,
        path: objectPath,
        bytes: thumbnailData,
        contentType: 'image/jpeg',
      );
      
      print('✅ Thumbnail uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading thumbnail: $e');
      return null;
    }
  }

  /// Оновлює документ відео з URL thumbnail
  Future<void> _updateVideoThumbnail(String videoId, String thumbnailUrl) async {
    try {
      await _sb.from('videos').update(<String, dynamic>{
        'thumbnail_url': thumbnailUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', videoId);

      print('✅ Video document updated with thumbnail URL');
    } catch (e) {
      print('❌ Error updating video with thumbnail: $e');
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
        // На веб-платформі використовуємо WebThumbnailService
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

      // Оновлюємо челендж з thumbnail
      await _sb.from('challenges').update(<String, dynamic>{
        'image_url': downloadUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', challengeId);

      print('✅ Challenge thumbnail generated: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error generating challenge thumbnail: $e');
      return null;
    }
  }

  /// Генерує thumbnail для відео учасника челенджу
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

      // Оновлюємо submission з thumbnail
      await _sb.from('challenge_submissions').update(<String, dynamic>{
        'thumbnail_url': downloadUrl,
      }).eq('id', submissionId);

      print('✅ Submission thumbnail generated: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error generating submission thumbnail: $e');
      return null;
    }
  }

  /// Перевіряє чи потрібно генерувати thumbnail для відео
  Future<bool> needsThumbnail(String videoId) async {
    try {
      final row =
          await _sb.from('videos').select('thumbnail_url').eq('id', videoId).maybeSingle();
      if (row == null) return false;
      final thumbnailUrl = row['thumbnail_url'] as String?;

      // Потрібен thumbnail якщо його немає або він не згенерований
      return thumbnailUrl == null || thumbnailUrl.isEmpty;
    } catch (e) {
      print('Error checking thumbnail status: $e');
      return true; // Якщо помилка, краще згенерувати
    }
  }

  /// Масове генерування thumbnails для існуючих відео
  Future<void> generateMissingThumbnails() async {
    try {
      print('🔄 Starting bulk thumbnail generation...');
      
      // Отримуємо відео без thumbnails
      final videosQuery = await _sb
          .from('videos')
          .select('id,video_url,user_id,thumbnail_url')
          .isFilter('thumbnail_url', null)
          .limit(10) // Обробляємо по 10 за раз
          ;

      final rows = videosQuery as List<dynamic>;
      print('📊 Found ${rows.length} videos without thumbnails');

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
          
          // Невелика затримка між генераціями
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      print('✅ Bulk thumbnail generation completed');
    } catch (e) {
      print('❌ Error in bulk thumbnail generation: $e');
    }
  }
}
