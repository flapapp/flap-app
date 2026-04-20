import '../entities/mode_news_item.dart';

abstract class ModeNewsRepository {
  /// Latest cross-feature highlights for the dashboard rail (newest first).
  Future<List<ModeNewsItem>> loadFeed({int limit = 3});
}
