import 'package:flutter/material.dart';

/// Username + capped description above bottom safe padding (TikTok-style).
class FeedBottomCaptionBlock extends StatelessWidget {
  const FeedBottomCaptionBlock({
    super.key,
    required this.username,
    required this.description,
    required this.bottomPadding,
  });

  final String username;
  final String description;

  /// Bottom inset (e.g. home indicator) so text clears system chrome.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 88, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              shadows: [
                Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.35,
              shadows: const [
                Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black87),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
