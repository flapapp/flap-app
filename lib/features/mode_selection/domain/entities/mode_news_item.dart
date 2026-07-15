import 'mode_navigation_target.dart';
import 'mode_news_icon_kind.dart';

class ModeNewsItem {
  const ModeNewsItem({
    this.titleKey,
    this.titleNamedArgs = const {},
    required this.titleRaw,
    required this.subtitleKey,
    this.subtitleNamedArgs = const {},
    required this.iconKind,
    required this.accentArgb,
    required this.timestamp,
    required this.navigationTarget,
    required this.ctaLabelKey,
    this.imageUrl,
  });

  /// When set, headline uses `tr(titleKey, namedArgs: titleNamedArgs)`.
  final String? titleKey;

  /// Named placeholders for `{name}` in [titleKey].
  final Map<String, String> titleNamedArgs;

  /// Shown when [titleKey] is null (e.g. DB titles).
  final String titleRaw;

  /// easy_localization key for subtitle body.
  final String subtitleKey;

  /// Named placeholders for `{name}` in [subtitleKey].
  final Map<String, String> subtitleNamedArgs;

  final ModeNewsIconKind iconKind;
  final int accentArgb;
  final DateTime timestamp;
  final ModeNavigationTarget navigationTarget;

  /// easy_localization key for the CTA label (existing app keys).
  final String ctaLabelKey;

  /// Optional artwork for the card's header band (video thumbnail, team crest).
  /// When null the card falls back to the accent gradient + [iconKind] glyph.
  final String? imageUrl;
}
