import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flap_app/core/media/flap_media_caches.dart';

/// Disk-backed network image using [FlapMediaCaches.images].
///
/// Prefer this over [Image.network] for any repeating remote URL (avatars, thumbs).
/// By default there is no loading spinner (avatars stay calm); pass [placeholder]
/// when you want an explicit loading UI.
class FlapCachedImage extends StatelessWidget {
  const FlapCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: FlapMediaCaches.images,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: memCacheWidth ?? width?.toInt(),
      memCacheHeight: memCacheHeight ?? height?.toInt(),
      placeholder: placeholder ??
          (_, __) => const ColoredBox(color: Colors.transparent),
      errorWidget: errorWidget ??
          (_, __, ___) => ColoredBox(
                color: Colors.white10,
                child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: (width ?? 48) * 0.4),
              ),
    );
  }
}

/// [ImageProvider] for [DecorationImage] / [CircleAvatar] that uses the image cache.
CachedNetworkImageProvider flapCachedImageProvider(String url) {
  return CachedNetworkImageProvider(
    url,
    cacheManager: FlapMediaCaches.images,
  );
}

