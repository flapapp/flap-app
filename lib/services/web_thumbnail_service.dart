import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebThumbnailService {
  static final WebThumbnailService _instance = WebThumbnailService._internal();
  factory WebThumbnailService() => _instance;
  WebThumbnailService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Генерує thumbnail для веб-платформи використовуючи VideoPlayer
  Future<String?> generateWebThumbnail({
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('🌐 Starting web thumbnail generation for: $videoId');

      // Створюємо VideoPlayerController
      final controller = VideoPlayerController.network(videoUrl);
      
      await controller.initialize();
      
      // Переходимо до 1-ї секунди
      await controller.seekTo(const Duration(seconds: 1));
      
      // Чекаємо щоб кадр завантажився
      await Future.delayed(const Duration(milliseconds: 500));
      
      // На веб-платформі створюємо простий placeholder з інформацією про відео
      final thumbnailUrl = await _createWebPlaceholder(
        videoId: videoId,
        userId: userId,
        videoUrl: videoUrl,
      );

      // Очищуємо ресурси
      await controller.dispose();

      return thumbnailUrl;
    } catch (e) {
      print('❌ Error generating web thumbnail: $e');
      return null;
    }
  }

  /// Створює placeholder для веб-платформи
  Future<String?> _createWebPlaceholder({
    required String videoId,
    required String userId,
    required String videoUrl,
  }) async {
    try {
      // Для веб-платформи використовуємо спеціальний URL який вказує на відео
      // Це дозволить браузеру показувати перший кадр автоматично
      final placeholderUrl = 'web_placeholder_$videoId';
      
      // Оновлюємо документ з placeholder URL
      await _firestore
          .collection('videos')
          .doc(videoId)
          .update({
        'thumbnailUrl': videoUrl, // Використовуємо сам відео URL як thumbnail
        'thumbnailGenerated': true,
        'thumbnailType': 'web_video_preview',
        'thumbnailUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Web placeholder created for: $videoId');
      return videoUrl; // Повертаємо URL відео як thumbnail
    } catch (e) {
      print('❌ Error creating web placeholder: $e');
      return null;
    }
  }

  /// Генерує thumbnail для челенджу
  Future<String?> generateWebChallengeThumbnail({
    required String videoUrl,
    required String challengeId,
    required String userId,
  }) async {
    try {
      // Для челенджів також використовуємо відео URL
      await _firestore
          .collection('challenges')
          .doc(challengeId)
          .update({
        'creatorThumbnailUrl': videoUrl,
        'thumbnailGenerated': true,
        'thumbnailType': 'web_video_preview',
      });

      print('✅ Web challenge thumbnail created: $challengeId');
      return videoUrl;
    } catch (e) {
      print('❌ Error creating web challenge thumbnail: $e');
      return null;
    }
  }
}
