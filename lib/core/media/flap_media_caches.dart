import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// App-wide HTTP media caches: separate stores for images vs full video files.
abstract final class FlapMediaCaches {
  /// Thumbnails, avatars, in-feed stills — higher object count, longer retention.
  static final CacheManager images = CacheManager(
    Config(
      'flapImageCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: 'flapImageCache'),
      fileService: HttpFileService(),
    ),
  );

  /// Full video files — fewer objects to cap disk use; LRU eviction via cache_manager.
  static final CacheManager video = CacheManager(
    Config(
      'flapVideoCache',
      stalePeriod: const Duration(days: 5),
      maxNrOfCacheObjects: 32,
      repo: JsonCacheInfoRepository(databaseName: 'flapVideoCache'),
      fileService: HttpFileService(),
    ),
  );
}
