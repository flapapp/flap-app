import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../ratings/domain/repositories/ratings_repository.dart';
import '../utils/team_roster_rating_total.dart';

/// Bolt + **total** roster rating (sum of formed team members’ ratings).
///
/// Caches the async result per roster signature so parent rebuilds do not restart
/// the [Future] every frame (which broke values / caused flicker).
class TeamRosterTotalRatingBadge extends StatefulWidget {
  const TeamRosterTotalRatingBadge({
    super.key,
    required this.playerIds,
    required this.accent,
    this.iconSize = 17,
    this.fontSize = 15,
    this.padding = const EdgeInsets.only(right: 10),
    this.showTotalRatingLabel = false,
    this.tooltipTranslationKey = 'il_0d5e3f5337',
  });

  final List<String> playerIds;
  final Color accent;
  final double iconSize;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool showTotalRatingLabel;
  final String tooltipTranslationKey;

  @override
  State<TeamRosterTotalRatingBadge> createState() =>
      _TeamRosterTotalRatingBadgeState();
}

class _TeamRosterTotalRatingBadgeState extends State<TeamRosterTotalRatingBadge> {
  Future<double>? _future;

  List<String> get _cleanIds => widget.playerIds
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _assignFutureForCurrentIds() {
    final ids = _cleanIds;
    _future =
        ids.isEmpty ? null : teamRosterTotalRating(
              supabase: Supabase.instance.client,
              ratingsRepo: sl<RatingsRepository>(),
              playerIds: ids,
            );
  }

  @override
  void initState() {
    super.initState();
    _assignFutureForCurrentIds();
  }

  @override
  void didUpdateWidget(covariant TeamRosterTotalRatingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSig = teamRosterSignature(
      oldWidget.playerIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
    final newSig = teamRosterSignature(_cleanIds);
    if (oldSig != newSig) {
      setState(_assignFutureForCurrentIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ids = _cleanIds;
    if (ids.isEmpty) return const SizedBox.shrink();

    final ratingsRepo = sl<RatingsRepository>();
    final future = _future;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<double>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Padding(
            padding: widget.padding,
            child: SizedBox(
              width: widget.iconSize,
              height: widget.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.accent,
              ),
            ),
          );
        }

        var total = 0.0;
        if (snapshot.hasData) {
          total = snapshot.data!;
        } else if (snapshot.hasError) {
          total = ratingsRepo.getDefaultRating() * ids.length;
        } else {
          total = snapshot.data ?? 0.0;
        }

        if (total <= 0 && ids.isNotEmpty) {
          total = ratingsRepo.getDefaultRating() * ids.length;
        }

        final valueText = Text(
          total.toStringAsFixed(2),
          style: TextStyle(
            color: widget.accent,
            fontWeight: FontWeight.w800,
            fontSize: widget.fontSize,
          ),
        );

        final boltRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: widget.accent, size: widget.iconSize),
            const SizedBox(width: 4),
            valueText,
          ],
        );

        final content = widget.showTotalRatingLabel
            ? Row(
                children: [
                  boltRow,
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(widget.tooltipTranslationKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              )
            : boltRow;

        return Padding(
          padding: widget.padding,
          child: Tooltip(
            message: tr(widget.tooltipTranslationKey),
            child: content,
          ),
        );
      },
    );
  }
}
