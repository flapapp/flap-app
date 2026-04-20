import '../../domain/entities/mode_news_item.dart';

abstract class ModeDashboardRemoteDataSource {
  Future<ModeNewsItem?> fetchLatestMatchHighlight();

  Future<ModeNewsItem?> fetchLatestVideoHighlight();

  Future<ModeNewsItem?> fetchLatestTeamHighlight();

  /// Recent roster joins (newest first), excluding rows we cannot resolve.
  Future<List<ModeNewsItem>> fetchRecentTeamJoins({int limit = 20});
}
