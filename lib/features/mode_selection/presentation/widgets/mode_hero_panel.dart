import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/flap/flap_kit.dart';
import '../../../../widgets/player_avatar_button.dart';
import '../../domain/entities/mode_hero_stats.dart';
import '../cubit/mode_selection_cubit.dart';

/// Home reputation hero (`.hero` in the design): identity + rating + 3 stat
/// pills (Matches / Win rate / FL Coins) + a "Last 5" form strip.
class ModeHeroPanel extends StatelessWidget {
  const ModeHeroPanel({
    super.key,
    required this.cubit,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.subtitle,
    required this.rating,
    required this.matchesLabel,
    required this.coinsLabel,
    this.greeting = '',
    this.onRefreshGreeting,
  });

  final ModeSelectionCubit cubit;
  final String userId;
  final String displayName;
  final String? avatarUrl;

  /// Position · city line (e.g. "Forward · Kyiv"), already localized.
  final String subtitle;
  final double rating;
  final String matchesLabel;
  final String coinsLabel;

  /// Personalized, randomly-rolled motivational greeting shown at the top of
  /// the card. Hidden when empty.
  final String greeting;

  /// Re-rolls [greeting] (wired to the "Refresh" button).
  final VoidCallback? onRefreshGreeting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x294CAF50), Color(0x05FFFFFF)], // .16 green -> .02 white
          stops: [0.0, 0.42],
        ),
        color: FlapColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FlapColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- personalized greeting + refresh (stacked vertically so the
          // phrase gets the full card width) ----
          if (greeting.isNotEmpty) ...[
            Text(
              greeting,
              softWrap: true,
              style: FlapText.sora(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: FlapColors.greenBright,
                height: 1.3,
              ),
            ),
            if (onRefreshGreeting != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _RefreshGreetingButton(onTap: onRefreshGreeting!),
              ),
            ],
            const SizedBox(height: 16),
          ],
          // ---- identity row + rating ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PlayerAvatarButton(
                userId: userId,
                displayName: displayName,
                avatarUrl: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? avatarUrl
                    : null,
                size: 52,
                backgroundColor: FlapColors.green,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlapText.sora(
                          fontSize: 12.5,
                          color: FlapColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rating.toStringAsFixed(2),
                        style: FlapText.cond(
                          fontSize: 34,
                          height: 0.9,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '/5',
                        style: FlapText.cond(
                          fontSize: 18,
                          color: FlapColors.greenBright,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    tr('il_9f29530464'), // "Rating"
                    style: FlapText.sora(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: FlapColors.muted,
                      letterSpacing: 1.9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // ---- stat pills + form strip (depend on async finished-match form) ----
          FutureBuilder<ModeHeroStats>(
            future: cubit.state.heroStatsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data ?? ModeHeroStats.empty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FlapStatPill(
                          value: matchesLabel,
                          label: tr('il_98abff28a9'), // "Matches"
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FlapStatPill(
                          value: '${stats.winRate.toStringAsFixed(0)}%',
                          label: tr('il_4be2547225'), // "Win rate"
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FlapStatPill(
                          value: coinsLabel,
                          label: tr('mode_fl_coins_label'),
                          icon: Icons.monetization_on_outlined,
                          valueColor: FlapColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          tr('mode_last_five').toUpperCase(),
                          style: FlapText.sora(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: FlapColors.muted,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      for (final r in stats.recentResults.take(5)) ...[
                        const SizedBox(width: 6),
                        FlapResultChip(result: r),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact "Refresh" affordance (icon + label) that re-rolls the greeting.
class _RefreshGreetingButton extends StatelessWidget {
  const _RefreshGreetingButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x0DFFFFFF), // rgba(255,255,255,.05)
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FlapColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded,
                  size: 15, color: FlapColors.greenBright),
              const SizedBox(width: 5),
              Text(
                tr('mode_greeting_refresh'),
                style: FlapText.sora(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: FlapColors.greenBright,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
