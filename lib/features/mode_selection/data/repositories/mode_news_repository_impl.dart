import '../../domain/entities/mode_news_icon_kind.dart';
import '../../domain/entities/mode_news_item.dart';
import '../../domain/entities/mode_navigation_target.dart';
import '../../domain/repositories/mode_news_repository.dart';
import '../datasources/mode_dashboard_remote_datasource.dart';

class ModeNewsRepositoryImpl implements ModeNewsRepository {
  ModeNewsRepositoryImpl(this._remote);

  final ModeDashboardRemoteDataSource _remote;

  static ModeNewsItem _defaultFeedItem() {
    return ModeNewsItem(
      titleKey: 'mode_news_default_headline',
      titleNamedArgs: const {},
      titleRaw: '',
      subtitleKey: 'mode_news_default_subtitle',
      subtitleNamedArgs: const {},
      iconKind: ModeNewsIconKind.flash,
      accentArgb: 0xFF7e57c2,
      timestamp: DateTime.now(),
      navigationTarget: ModeNavigationTarget.matches,
      ctaLabelKey: 'il_0c910eec13',
    );
  }

  @override
  Future<List<ModeNewsItem>> loadFeed({int limit = 3}) async {
    try {
      // Run the highlights and the team-join movement concurrently. The feed
      // only renders `limit` items after the merge/sort, so there's no point
      // fetching more joins than that.
      final highlightsFuture = Future.wait<ModeNewsItem?>([
        _remote.fetchLatestMatchHighlight(),
        _remote.fetchLatestVideoHighlight(),
        _remote.fetchLatestTeamHighlight(),
      ]);
      final movementFuture = _remote.fetchRecentTeamJoins(limit: limit);
      final results = await highlightsFuture;
      final movement = await movementFuture;

      final available = <ModeNewsItem>[
        ...results.whereType<ModeNewsItem>(),
        ...movement,
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (available.isEmpty) {
        return [_defaultFeedItem()];
      }
      return available.take(limit).toList(growable: false);
    } catch (_) {
      return [_defaultFeedItem()];
    }
  }
}
