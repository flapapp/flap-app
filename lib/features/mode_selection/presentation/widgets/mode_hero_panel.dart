import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../widgets/player_avatar_button.dart';
import '../../domain/entities/mode_hero_stats.dart';
import '../cubit/mode_selection_cubit.dart';

class ModeHeroPanel extends StatelessWidget {
  const ModeHeroPanel({
    super.key,
    required this.cubit,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.rating,
    required this.matchesLabel,
    required this.coinsLabel,
    required this.greeting,
    required this.ratingLine,
    required this.onRefreshGreeting,
  });

  final ModeSelectionCubit cubit;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double rating;
  final String matchesLabel;
  final String coinsLabel;
  final String greeting;
  final String ratingLine;
  final VoidCallback onRefreshGreeting;

  @override
  Widget build(BuildContext context) {
    final heroStatsFuture = cubit.state.heroStatsFuture;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 560;
        final persona = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlayerAvatarButton(
              userId: userId,
              displayName: displayName,
              avatarUrl: avatarUrl != null && avatarUrl!.isNotEmpty ? avatarUrl : null,
              size: 84,
              backgroundColor: Colors.white,
              borderColor: Colors.white.withValues(alpha: 0.2),
              borderWidth: 2,
            ),
            const SizedBox(height: 12),
            Text(
              tr('il_0a2d828e92'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              greeting,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ratingLine,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRefreshGreeting,
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
              label: Text(
                tr('il_15b1a29fbf'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          ],
        );

        final statGrid = Row(
          children: [
            Expanded(
              child: _HeroPill(
                icon: Icons.star,
                value: rating.toStringAsFixed(2),
                label: tr('il_9f29530464'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeroPill(
                icon: Icons.sports_soccer,
                value: matchesLabel,
                label: tr('il_98abff28a9'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HeroPill(
                icon: Icons.monetization_on_outlined,
                value: coinsLabel,
                label: 'FL Coins',
              ),
            ),
          ],
        );

        final winRateCard = _WinRateCard(statsFuture: heroStatsFuture);

        final content = isWide
            ? Row(
                children: [
                  Expanded(child: persona),
                  Container(
                    width: 1,
                    height: 160,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statGrid,
                        const SizedBox(height: 18),
                        winRateCard,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  persona,
                  const SizedBox(height: 18),
                  statGrid,
                  const SizedBox(height: 18),
                  winRateCard,
                ],
              );

        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF121F2E), Color(0xFF080E18)],
              ),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 32,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: content,
          ),
        );
      },
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WinRateCard extends StatelessWidget {
  const _WinRateCard({required this.statsFuture});

  final Future<ModeHeroStats>? statsFuture;

  @override
  Widget build(BuildContext context) {
    final baseDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      color: Colors.white.withValues(alpha: 0.04),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );
    if (statsFuture == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: baseDecoration,
        child: _buildWinRateContent(ModeHeroStats.empty),
      );
    }

    return FutureBuilder<ModeHeroStats>(
      future: statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? ModeHeroStats.empty;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: baseDecoration,
          child: _buildWinRateContent(stats),
        );
      },
    );
  }

  Widget _buildWinRateContent(ModeHeroStats stats) {
    final trend = '${stats.wins}W · ${stats.draws}D · ${stats.losses}L';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF1de9b6), Color(0xFF42a5f5)],
                ),
              ),
              child: const Icon(Icons.insights, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('il_4be2547225'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${stats.winRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              trend,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stats.recentResults
              .take(5)
              .map((result) => _ResultChip(result: result))
              .toList(),
        ),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    Color color;
    String display = result;
    switch (result) {
      case 'W':
        color = const Color(0xFF4CAF50);
      case 'D':
        color = const Color(0xFFFFC107);
      case 'L':
        color = const Color(0xFFF44336);
      default:
        color = Colors.white24;
        display = '-';
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.8)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Text(
          display,
          style: TextStyle(
            color: color == Colors.white24 ? Colors.white54 : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
