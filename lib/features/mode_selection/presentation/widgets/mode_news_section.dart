import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../app_locale_access.dart';
import '../../domain/entities/mode_news_icon_kind.dart';
import '../../domain/entities/mode_news_item.dart';
import '../navigation/mode_selection_router.dart';

class ModeNewsSection extends StatelessWidget {
  const ModeNewsSection({
    super.key,
    required this.loading,
    required this.items,
  });

  final bool loading;
  final List<ModeNewsItem> items;

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
      return tr('il_481b95953d');
    }
    if (diff.inHours < 24) {
      return tr('il_027c01229b');
    }
    return '${timestamp.day.toString().padLeft(2, '0')}.${timestamp.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                tr('il_6eb4de330e'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    final display = items.isNotEmpty ? items : const <ModeNewsItem>[];

    return Column(
      children: [
        for (int i = 0; i < display.length; i++) ...[
          _NewsCardItem(
            entry: display[i],
            primary: i == 0,
          ),
          if (i != display.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _NewsCardItem extends StatelessWidget {
  const _NewsCardItem({
    required this.entry,
    required this.primary,
  });

  final ModeNewsItem entry;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = Color(entry.accentArgb);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.5)],
                  ),
                ),
                child: Text(
                  primary ? tr('il_e51c4cffae') : tr('il_e07805a8bf'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                ModeNewsSection.formatNewsTime(entry.timestamp),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            bilingual(entry.titleUa, entry.titleEn),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bilingual(entry.subtitleUa, entry.subtitleEn),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(ModeNewsSection.iconFor(entry.iconKind), color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  tr('il_9c351cb885'),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.pushModeTarget(entry.navigationTarget),
              icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
              label: Text(
                tr(entry.ctaLabelKey),
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
