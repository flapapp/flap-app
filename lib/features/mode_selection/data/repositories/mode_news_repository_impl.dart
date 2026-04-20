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
      titleUa: 'FLAP Live',
      titleEn: 'FLAP Live',
      subtitleUa: 'Слідкуй за матчами та відео у реальному часі',
      subtitleEn: 'Watch matches and videos in real time',
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
      final results = await Future.wait<ModeNewsItem?>([
        _remote.fetchLatestMatchHighlight(),
        _remote.fetchLatestVideoHighlight(),
        _remote.fetchLatestTeamHighlight(),
      ]);
      final movement = await _remote.fetchRecentTeamJoins(limit: 20);

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
