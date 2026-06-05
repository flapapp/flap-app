import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../theme/flap_tokens.dart';
import '../../../../widgets/user_chip.dart';

/// Compact “waiting list” for users who applied to join but are not confirmed.
/// Shows an overlapping avatar preview, total count, and an overflow chip when
/// [pendingUserIds] is longer than [maxAvatarPreview].
class MatchWaitingListStrip extends StatelessWidget {
  const MatchWaitingListStrip({
    super.key,
    required this.pendingUserIds,
    this.maxAvatarPreview = 5,
  });

  final List<String> pendingUserIds;
  final int maxAvatarPreview;

  static const double _avatarSize = 22;
  static const double _overlap = 13;

  // Restrained gold accent matching the design's pending/invite tokens.
  static const Color _tint = Color(0x12E7C25A); // gold ~7%
  static const Color _tintBorder = Color(0x2EE7C25A); // gold ~18%

  @override
  Widget build(BuildContext context) {
    final ids = pendingUserIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const SizedBox.shrink();

    final total = ids.length;
    final previewCount = total > maxAvatarPreview ? maxAvatarPreview : total;
    final preview = ids.take(previewCount).toList();
    final overflowExtra = total > maxAvatarPreview ? total - maxAvatarPreview : 0;
    final stackWidth = preview.isEmpty
        ? 0.0
        : _avatarSize + (preview.length - 1) * _overlap;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 17,
                color: FlapColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('match_waiting_list_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('match_waiting_list_subtitle'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FlapText.sora(
                        fontSize: 11.5,
                        color: FlapColors.muted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                tr(
                  'match_waiting_list_total_badge',
                  namedArgs: {'count': '$total'},
                ),
                style: FlapText.sora(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: FlapColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (stackWidth > 0)
                  SizedBox(
                    width: stackWidth,
                    height: _avatarSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < preview.length; i++)
                          Positioned(
                            left: i * _overlap,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: FlapColors.card,
                                  width: 2,
                                ),
                              ),
                              child: UserChip(
                                userId: preview[i],
                                size: _avatarSize,
                                showName: false,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (overflowExtra > 0) ...[
                  if (stackWidth > 0) const SizedBox(width: 10),
                  _OverflowChip(count: overflowExtra, avatarSize: _avatarSize),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({
    required this.count,
    required this.avatarSize,
  });

  final int count;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: avatarSize,
      constraints: const BoxConstraints(minWidth: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FlapColors.border),
      ),
      child: Text(
        tr('match_waiting_list_overflow', namedArgs: {'count': '$count'}),
        style: FlapText.sora(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
