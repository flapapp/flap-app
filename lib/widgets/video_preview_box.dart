import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'web_video_thumbnail.dart';

class VideoPreviewBox extends StatefulWidget {
  final String? thumbnailUrl;
  final String? videoUrl;
  final double borderRadius;
  final double aspectRatio;
  final VoidCallback? onTap;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottomLeft;
  final Widget? bottomRight;
  final Widget? centerOverlay;
  final bool showPlayIcon;
  final Color placeholderColor;

  const VideoPreviewBox({
    super.key,
    this.thumbnailUrl,
    this.videoUrl,
    this.borderRadius = 16,
    this.aspectRatio = 16 / 9,
    this.onTap,
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.centerOverlay,
    this.showPlayIcon = true,
    this.placeholderColor = const Color(0xFF101020),
  });

  @override
  State<VideoPreviewBox> createState() => _VideoPreviewBoxState();
}

class _VideoPreviewBoxState extends State<VideoPreviewBox> {
  static final Map<String, Uint8List> _thumbMemoryCache = {};
  Uint8List? _localThumb;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _maybeGenerateThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoPreviewBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _localThumb = null;
      _maybeGenerateThumbnail();
    }
  }

  Future<void> _maybeGenerateThumbnail() async {
    final thumbUrl = widget.thumbnailUrl;
    final hasImageThumb =
        thumbUrl != null && thumbUrl.isNotEmpty && !_looksLikeVideoUrl(thumbUrl);
    if (hasImageThumb) return;

    if (kIsWeb) return;

    final videoUrl = (widget.videoUrl?.isNotEmpty == true)
        ? widget.videoUrl
        : ((_looksLikeVideoUrl(thumbUrl ?? '')) ? thumbUrl : null);
    if (videoUrl == null || videoUrl.isEmpty) return;
    if (_thumbMemoryCache.containsKey(videoUrl)) {
      setState(() => _localThumb = _thumbMemoryCache[videoUrl]);
      return;
    }
    if (_isGenerating) return;
    _isGenerating = true;
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 256,
        quality: 60,
        timeMs: 1000,
      );
      if (data != null) {
        _thumbMemoryCache[videoUrl] = data;
        if (mounted) {
          setState(() => _localThumb = data);
        }
      }
    } catch (_) {
      // ignore generation errors
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMedia(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            if (widget.centerOverlay != null) widget.centerOverlay!,
            if (widget.showPlayIcon)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.play_arrow, color: Colors.white, size: 42),
                  ),
                ),
              ),
            if (widget.topLeft != null)
              Positioned(
                top: 10,
                left: 10,
                child: widget.topLeft!,
              ),
            if (widget.topRight != null)
              Positioned(
                top: 10,
                right: 10,
                child: widget.topRight!,
              ),
              if (widget.bottomLeft != null)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: widget.bottomLeft!,
                ),
              if (widget.bottomRight != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: widget.bottomRight!,
                ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return content;
    return GestureDetector(
      onTap: widget.onTap,
      child: content,
    );
  }

  Widget _buildMedia() {
    final thumbUrl = widget.thumbnailUrl;
    if (thumbUrl != null &&
        thumbUrl.isNotEmpty &&
        !_looksLikeVideoUrl(thumbUrl)) {
      return Image.network(
        thumbUrl,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        cacheWidth: 720,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    if (_localThumb != null) {
      return Image.memory(
        _localThumb!,
        fit: BoxFit.cover,
      );
    }

    final previewVideoUrl = (widget.videoUrl?.isNotEmpty == true)
        ? widget.videoUrl!
        : ((_looksLikeVideoUrl(thumbUrl ?? '')) ? thumbUrl! : '');

    if (kIsWeb && previewVideoUrl.isNotEmpty) {
      return WebVideoThumbnail(
        videoUrl: previewVideoUrl,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      );
    }

    // Web video frame extraction is expensive for large lists.
    // A fast placeholder keeps scrolling responsive; full video is loaded on open.
    return _buildPlaceholder();
  }

  bool _looksLikeVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('.mp4') ||
        u.contains('.mov') ||
        u.contains('.webm') ||
        u.contains('video');
  }

  Widget _buildPlaceholder() {
    return Container(
      color: widget.placeholderColor,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white24, size: 48),
      ),
    );
  }
}












