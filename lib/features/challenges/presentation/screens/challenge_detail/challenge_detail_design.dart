import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/utils/i18n.dart';

/// Visual tokens: dark surfaces + single primary green accent.
abstract final class CdpColors {
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryMuted = Color(0xFF2E7D32);
  static const Color bgDeep = Color(0xFF050608);
  static const Color bgElevated = Color(0xFF0E1117);
  static const Color bgCard = Color(0xFF141922);
  static const Color stroke = Color(0xFF252A34);
  static const Color textPrimary = Color(0xFFE8ECF2);
  static const Color textSecondary = Color(0xFF8B95A8);
  static const Color glow = Color(0x334CAF50);
}

/// Phase copy + accent for the hero strip (green-only accents; neutrals for non-live states).
String cdpStatusHeadline(Challenge c, DateTime now) {
  switch (c.status) {
    case ChallengeStatus.recruiting:
      return I18n.inline('Відкрито набір', 'Open for players');
    case ChallengeStatus.submission:
      return I18n.inline('Прийом відео', 'Accepting clips');
    case ChallengeStatus.voting:
      return I18n.inline('Триває голосування', 'Voting live');
    case ChallengeStatus.completed:
      return I18n.inline('Челендж завершено', 'Challenge closed');
  }
}

String cdpAudienceLabel(ChallengeAudience a) {
  switch (a) {
    case ChallengeAudience.friends:
      return I18n.inline('Друзі', 'Friends');
    case ChallengeAudience.city:
      return I18n.inline('Місто', 'City');
    case ChallengeAudience.country:
      return I18n.inline('Країна', 'Country');
    case ChallengeAudience.world:
      return I18n.inline('Світ', 'Worldwide');
  }
}

class CdpMeshBackdrop extends StatelessWidget {
  const CdpMeshBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF06080C),
                Color(0xFF0A0E14),
                Color(0xFF050608),
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CdpColors.primary.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -40,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 64, sigmaY: 64),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CdpColors.primaryMuted.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class CdpSectionLabel extends StatelessWidget {
  const CdpSectionLabel({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: CdpColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: CdpColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class CdpGlassCard extends StatelessWidget {
  const CdpGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: CdpColors.bgCard.withValues(alpha: 0.92),
        border: Border.all(color: CdpColors.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: inner,
      ),
    );
  }
}

class CdpMetaRail extends StatelessWidget {
  const CdpMetaRail({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class CdpMetaPill extends StatelessWidget {
  const CdpMetaPill({
    super.key,
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: emphasize
            ? CdpColors.primary.withValues(alpha: 0.14)
            : CdpColors.bgElevated,
        border: Border.all(
          color: emphasize ? CdpColors.primary.withValues(alpha: 0.35) : CdpColors.stroke,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: emphasize ? CdpColors.primary : CdpColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: emphasize ? CdpColors.textPrimary : CdpColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CdpTimeline extends StatelessWidget {
  const CdpTimeline({
    super.key,
    required this.entries,
  });

  final List<CdpTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class CdpTimelineEntry {
  const CdpTimelineEntry({
    required this.title,
    required this.subtitle,
    required this.isPast,
  });

  final String title;
  final String subtitle;
  final bool isPast;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final CdpTimelineEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = entry.isPast ? CdpColors.primary : CdpColors.textSecondary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: CdpColors.stroke,
                    ),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CdpColors.bgDeep,
                    border: Border.all(color: dotColor, width: 2),
                    boxShadow: entry.isPast
                        ? [
                            BoxShadow(
                              color: CdpColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: CdpColors.stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      color: CdpColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    style: const TextStyle(
                      color: CdpColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CdpPrimaryCta extends StatelessWidget {
  const CdpPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.upload_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), CdpColors.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: CdpColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CdpSecondaryCta extends StatelessWidget {
  const CdpSecondaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_circle_outline_rounded,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: CdpColors.textPrimary,
        side: const BorderSide(color: CdpColors.stroke),
        backgroundColor: CdpColors.bgElevated,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: CdpColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class CdpSheetChrome extends StatelessWidget {
  const CdpSheetChrome({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CdpColors.bgDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: CdpColors.stroke)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CdpColors.stroke,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: CdpColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: CdpColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CdpColors.stroke),
          Expanded(child: child),
        ],
      ),
    );
  }
}
