import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class WebThumbnailService {
  static final WebThumbnailService _instance = WebThumbnailService._internal();
  factory WebThumbnailService() => _instance;
  WebThumbnailService._internal();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Генерує thumbnail для веб-платформи використовуючи VideoPlayer
  Future<String?> generateWebThumbnail({
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('🌐 Starting web thumbnail generation for: $videoId');

      // Створюємо VideoPlayerController
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      
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
      // Для веб: використовуємо саме відео як прев'ю, щоб браузер відобразив перший кадр
      await _sb.from('videos').update(<String, dynamic>{
        'thumbnail_url': videoUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', videoId);

      print('✅ Web placeholder created for: $videoId');
      return videoUrl;
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
      await _sb.from('challenges').update(<String, dynamic>{
        'image_url': videoUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', challengeId);

      print('✅ Web challenge thumbnail created: $challengeId');
      return videoUrl;
    } catch (e) {
      print('❌ Error creating web challenge thumbnail: $e');
      return null;
    }
  }
}
