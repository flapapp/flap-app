import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flap_app/features/videos/domain/repositories/videos_repository.dart';

class WebThumbnailService {
  static final WebThumbnailService _instance = WebThumbnailService._internal();
  factory WebThumbnailService() => _instance;
  WebThumbnailService._internal();

  /// Генерує thumbnail для веб-платформи використовуючи VideoPlayer
  Future<String?> generateWebThumbnail({
    required VideosRepository videosRepository,
    required String videoUrl,
    required String videoId,
    required String userId,
  }) async {
    try {
      print('🌐 Starting web thumbnail generation for: $videoId');

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await controller.initialize();

      await controller.seekTo(const Duration(seconds: 1));

      await Future.delayed(const Duration(milliseconds: 500));

      await videosRepository.setWebThumbnailToVideoUrl(videoId, videoUrl);

      await controller.dispose();

      print('✅ Web placeholder created for: $videoId');
      return videoUrl;
    } catch (e) {
      print('❌ Error generating web thumbnail: $e');
      return null;
    }
  }

  Future<String?> generateWebChallengeThumbnail({
    required String videoUrl,
    required String challengeId,
    required String userId,
  }) async {
    try {
      await Supabase.instance.client.rpc<void>(
        'challenge_set_creator_video',
        params: <String, dynamic>{
          'p_challenge_id': challengeId,
          'p_creator_video_url': '',
          'p_creator_thumbnail_url': videoUrl,
        },
      );

      print('✅ Web challenge thumbnail created: $challengeId');
      return videoUrl;
    } catch (e) {
      print('❌ Error creating web challenge thumbnail: $e');
      return null;
    }
  }
}
