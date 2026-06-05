import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../theme/flap_tokens.dart';
import '../../domain/entities/mode_news_icon_kind.dart';
import '../../domain/entities/mode_news_item.dart';
import '../navigation/mode_selection_router.dart';

/// "For you" horizontal news/activity strip (`.news` / `.newscard`).
class ModeNewsSection extends StatelessWidget {
  const ModeNewsSection({
    super.key,
    required this.loading,
    required this.items,
  });

  final bool loading;
  final List<ModeNewsItem> items;

  static const double _cardWidth = 230;
  static const double _stripHeight = 188;

  static IconData iconFor(ModeNewsIconKind kind) {
    switch (kind) {
      case ModeNewsIconKind.soccer:
        return Icons.sports_soccer;
      case ModeNewsIconKind.video:
        return Icons.play_circle_fill;
      case ModeNewsIconKind.groups:
        return Icons.groups;
      case ModeNewsIconKind.join:
        return Icons.person_add_alt_1;
      case ModeNewsIconKind.flash:
        return Icons.flash_on;
    }
  }

  static String formatNewsTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) {
      return tr('il_7ddb44d8a5');
    }
    if (diff.inHours < 1) {
      return tr('il_481b95953d', args: ['${diff.inMinutes}']);
    }
    if (diff.inHours < 24) {
      return tr('il_027c01229b', args: ['${diff.inHours}']);
    }
    return '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: _stripHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 2,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => _placeholderCard(),
        ),
      );
    }

    if (items.isEmpty) {
      return _placeholderCard(
        message: tr('il_9c351cb885'),
        full: true,
      );
    }

    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _NewsCardItem(
          entry: items[i],
          primary: i == 0,
        ),
      ),
    );
  }

  Widget _placeholderCard({String? message, bool full = false}) {
    final card = Container(
      width: full ? null : _cardWidth,
      margin: full ? const EdgeInsets.symmetric(horizontal: 20) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlapColors.border),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: message != null
          ? Text(
              message,
              textAlign: TextAlign.center,
              style: FlapText.sora(fontSize: 12.5, color: FlapColors.muted),
            )
          : null,
    );
    return full ? SizedBox(height: 96, child: card) : card;
  }
}

class _NewsCardItem extends StatelessWidget {
  const _NewsCardItem({required this.entry, required this.primary});

  final ModeNewsItem entry;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = Color(entry.accentArgb);
    final title = entry.titleKey != null
        ? tr(entry.titleKey!, namedArgs: entry.titleNamedArgs)
        : entry.titleRaw;
    final subtitle = tr(entry.subtitleKey, namedArgs: entry.subtitleNamedArgs);
    final tag = primary ? tr('il_e51c4cffae') : tr('il_e07805a8bf');

    return GestureDetector(
      onTap: () => context.pushModeTarget(entry.navigationTarget),
      child: Container(
        width: ModeNewsSection._cardWidth,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: FlapColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- artwork band with category tag ----
            Container(
              height: 108,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent.withValues(alpha: 0.2), Colors.transparent],
                ),
                color: const Color(0xFF0F1C16),
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      ModeNewsSection.iconFor(entry.iconKind),
                      color: accent.withValues(alpha: 0.55),
                      size: 34,
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xB3070A08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: FlapColors.border),
                      ),
                      child: Text(
                        tag.toUpperCase(),
                        style: FlapText.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---- title + subtitle ----
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                          fontSize: 11.5,
                          color: FlapColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
