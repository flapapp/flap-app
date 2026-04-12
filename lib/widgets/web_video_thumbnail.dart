import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:flap_app/core/media/cached_video_controller.dart';

class WebVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const WebVideoThumbnail({
    super.key,
    required this.videoUrl,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<WebVideoThumbnail> createState() => _WebVideoThumbnailState();
}

class _WebVideoThumbnailState extends State<WebVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initTried = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initController();
    }
  }

  Future<void> _initController() async {
    if (_initTried) return;
    _initTried = true;
    try {
      final controller = await createCachedVideoController(Uri.parse(widget.videoUrl));
      await controller.initialize();
      await controller.seekTo(const Duration(seconds: 1));
      await controller.pause();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = (kIsWeb && _controller != null && _controller!.value.isInitialized)
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        : Container(color: Colors.black54);

    final child = ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      child: SizedBox(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        child: content,
      ),
    );

    return child;
  }
}



