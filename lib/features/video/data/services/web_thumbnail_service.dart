import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class WebThumbnailService {
  static final WebThumbnailService _instance = WebThumbnailService._internal();
  factory WebThumbnailService() => _instance;
  WebThumbnailService._internal();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Generates a thumbnail on web using VideoPlayer
  Future<String?> generateWebThumbnail({
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('[web_thumb] Starting web thumbnail generation for: $videoId');

      // Create VideoPlayerController
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      
      await controller.initialize();
      
      // Seek to first second
      await controller.seekTo(const Duration(seconds: 1));
      
      // Wait for frame to load
      await Future.delayed(const Duration(milliseconds: 500));
      
      // On web, build a simple placeholder with video metadata
      final thumbnailUrl = await _createWebPlaceholder(
        videoId: videoId,
        userId: userId,
        videoUrl: videoUrl,
      );

      // Dispose resources
      await controller.dispose();

      return thumbnailUrl;
    } catch (e) {
      print('[web_thumb] ERROR generating web thumbnail: $e');
      return null;
    }
  }

  /// Creates a web placeholder thumbnail
  Future<String?> _createWebPlaceholder({
    required String videoId,
    required String userId,
    required String videoUrl,
  }) async {
    try {
      // On web, use the video URL as preview so the browser shows the first frame
      await _sb.from('videos').update(<String, dynamic>{
        'thumbnail_url': videoUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', videoId);

      print('[web_thumb] Web placeholder created for: $videoId');
      return videoUrl;
    } catch (e) {
      print('[web_thumb] ERROR creating web placeholder: $e');
      return null;
    }
  }

  /// Generates a thumbnail for a challenge video
  Future<String?> generateWebChallengeThumbnail({
    required String videoUrl,
    required String challengeId,
    required String userId,
  }) async {
    try {
      // For challenges, also use the video URL
      await _sb.from('challenges').update(<String, dynamic>{
        'image_url': videoUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', challengeId);

      print('[web_thumb] Web challenge thumbnail created: $challengeId');
      return videoUrl;
    } catch (e) {
      print('[web_thumb] ERROR creating web challenge thumbnail: $e');
      return null;
    }
  }
}
