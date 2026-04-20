import '../../domain/entities/mode_hero_stats.dart';
import '../../domain/entities/mode_news_item.dart';

class ModeSelectionState {
  const ModeSelectionState({
    this.profileDocument,
    this.greetingText = '',
    this.ratingLineText = '',
    this.newsItems = const [],
    this.newsLoading = true,
    this.heroStatsFuture,
  });

  final Map<String, dynamic>? profileDocument;
  final String greetingText;
  final String ratingLineText;
  final List<ModeNewsItem> newsItems;
  final bool newsLoading;
  final Future<ModeHeroStats>? heroStatsFuture;

  ModeSelectionState copyWith({
    Map<String, dynamic>? profileDocument,
    bool clearProfile = false,
    String? greetingText,
    String? ratingLineText,
    List<ModeNewsItem>? newsItems,
    bool? newsLoading,
    Future<ModeHeroStats>? heroStatsFuture,
    bool clearHeroFuture = false,
  }) {
    return ModeSelectionState(
      profileDocument:
          clearProfile ? null : (profileDocument ?? this.profileDocument),
      greetingText: greetingText ?? this.greetingText,
      ratingLineText: ratingLineText ?? this.ratingLineText,
      newsItems: newsItems ?? this.newsItems,
      newsLoading: newsLoading ?? this.newsLoading,
      heroStatsFuture:
          clearHeroFuture ? null : (heroStatsFuture ?? this.heroStatsFuture),
    );
  }
}
