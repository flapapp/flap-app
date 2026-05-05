import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/rating_snapshot_source_label.dart';

/// One snapshot in overall rating history: direction icon, source, Δ overall, new overall.
class RatingHistorySnapshotCard extends StatelessWidget {
  const RatingHistorySnapshotCard({
    super.key,
    required this.newRating,
    this.oldRating,
    this.delta,
    this.triggerSource,
    this.timeLabel,
    this.detailSubtitle,
  });

  /// Overall rating after this event.
  final double newRating;

  /// Overall rating before this event (previous snapshot).
  final double? oldRating;

  /// Change in overall rating vs [oldRating]; null = first / baseline row.
  final double? delta;

  /// [user_rating_snapshots.trigger_source], e.g. `video_rating`.
  final String? triggerSource;

  /// Optional footer line (relative or absolute time).
  final String? timeLabel;

  /// Extra line under the source badge (e.g. baseline explanation).
  final String? detailSubtitle;

  @override
  Widget build(BuildContext context) {
    final d = delta;
    final accent = ratingSnapshotSourceAccentColor(triggerSource);

    late final IconData dirIcon;
    late final Color dirColor;
    if (d == null) {
      dirIcon = Icons.flag_outlined;
      dirColor = Colors.white54;
    } else if (d > 0) {
      dirIcon = Icons.trending_up_rounded;
      dirColor = const Color(0xFF4caf50);
    } else if (d < 0) {
      dirIcon = Icons.trending_down_rounded;
      dirColor = Colors.redAccent;
    } else {
      dirIcon = Icons.trending_flat_rounded;
      dirColor = Colors.grey;
    }

    final Color impactColor;
    if (d == null) {
      impactColor = Colors.white70;
    } else if (d > 0) {
      impactColor = const Color(0xFF4caf50);
    } else if (d < 0) {
      impactColor = Colors.redAccent;
    } else {
      impactColor = Colors.white54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dirColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(dirIcon, color: dirColor, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.38)),
                  ),
                  child: Text(
                    ratingSnapshotSourceBadge(triggerSource),
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                if (detailSubtitle != null &&
                    detailSubtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detailSubtitle!.trim(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (d != null) ...[
                  _metricRow(
                    tr('rating_history_row_impact'),
                    '${d > 0 ? '+' : ''}${d.toStringAsFixed(2)}',
                    impactColor,
                    largeValue: false,
                  ),
                  const SizedBox(height: 8),
                ],
                _metricRow(
                  d == null
                      ? tr('rating_history_row_overall_at')
                      : tr('rating_history_row_overall_after'),
                  newRating.toStringAsFixed(2),
                  Colors.white,
                  largeValue: true,
                ),
                if (oldRating != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'rating_history_previous_overall',
                      namedArgs: {'v': oldRating!.toStringAsFixed(2)},
                    ),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (timeLabel != null && timeLabel!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    timeLabel!.trim(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metricRow(
    String label,
    String value,
    Color valueColor, {
    required bool largeValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: largeValue ? 20 : 15,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
