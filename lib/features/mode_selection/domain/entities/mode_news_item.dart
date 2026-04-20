import 'mode_navigation_target.dart';
import 'mode_news_icon_kind.dart';

class ModeNewsItem {
  const ModeNewsItem({
    required this.titleUa,
    required this.titleEn,
    required this.subtitleUa,
    required this.subtitleEn,
    required this.iconKind,
    required this.accentArgb,
    required this.timestamp,
    required this.navigationTarget,
    required this.ctaLabelKey,
  });

  final String titleUa;
  final String titleEn;
  final String subtitleUa;
  final String subtitleEn;
  final ModeNewsIconKind iconKind;
  final int accentArgb;
  final DateTime timestamp;
  final ModeNavigationTarget navigationTarget;

  /// easy_localization key for the CTA label (existing app keys).
  final String ctaLabelKey;
}
