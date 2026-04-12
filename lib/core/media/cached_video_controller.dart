import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';

import 'package:flap_app/core/media/flap_media_caches.dart';

/// Resolves a remote video through [FlapMediaCaches.video] when possible so
/// repeat views hit disk instead of the network.
Future<VideoPlayerController> createCachedVideoController(Uri uri) async {
  if (kIsWeb) {
    return VideoPlayerController.networkUrl(uri);
  }
  try {
    final file = await FlapMediaCaches.video.getSingleFile(uri.toString());
    return VideoPlayerController.file(file);
  } catch (_) {
    return VideoPlayerController.networkUrl(uri);
  }
}
