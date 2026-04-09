import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'web_thumbnail_service.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      final storageRef = _storage
          .ref()
          .child('thumbnails/$userId/$fileName');

      print('📤 Uploading thumbnail: thumbnails/$userId/$fileName');

      // Завантажуємо thumbnail
      final uploadTask = storageRef.putData(
        thumbnailData,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'videoId': videoId,
            'userId': userId,
            'generated': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
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
      await _firestore
          .collection('videos')
          .doc(videoId)
          .update({
        'thumbnailUrl': thumbnailUrl,
        'thumbnailGenerated': true,
        'thumbnailUpdatedAt': FieldValue.serverTimestamp(),
      });

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
      final storageRef = _storage
          .ref()
          .child('challenge_thumbnails/$userId/$fileName');

      final uploadTask = storageRef.putData(
        thumbnailData,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'challengeId': challengeId,
            'userId': userId,
            'type': 'challenge_creator',
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await Supabase.instance.client.rpc<void>(
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
      final storageRef = _storage
          .ref()
          .child('submission_thumbnails/$challengeId/$fileName');

      final uploadTask = storageRef.putData(
        thumbnailData,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'challengeId': challengeId,
            'submissionId': submissionId,
            'userId': userId,
            'type': 'submission',
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Оновлюємо submission з thumbnail
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .doc(submissionId)
          .update({
        'thumbnailUrl': downloadUrl,
        'thumbnailGenerated': true,
      });

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
      final doc = await _firestore.collection('videos').doc(videoId).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final thumbnailUrl = data['thumbnailUrl'] as String?;
      final thumbnailGenerated = data['thumbnailGenerated'] as bool? ?? false;

      // Потрібен thumbnail якщо його немає або він не згенерований
      return thumbnailUrl == null || thumbnailUrl.isEmpty || !thumbnailGenerated;
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
      final videosQuery = await _firestore
          .collection('videos')
          .where('thumbnailGenerated', isEqualTo: false)
          .limit(10) // Обробляємо по 10 за раз
          .get();

      print('📊 Found ${videosQuery.docs.length} videos without thumbnails');

      for (final doc in videosQuery.docs) {
        final data = doc.data();
        final videoUrl = data['videoUrl'] as String?;
        final userId = data['userId'] as String?;
        
        if (videoUrl != null && userId != null) {
          await generateAndUploadThumbnail(
            videoUrl: videoUrl,
            videoId: doc.id,
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
