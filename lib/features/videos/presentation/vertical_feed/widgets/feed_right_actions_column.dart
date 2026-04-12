import 'package:flutter/material.dart';

import 'package:flap_app/utils/i18n.dart';

/// Profile, like, comment, share stacked on the right (TikTok-style).
class FeedRightActionsColumn extends StatelessWidget {
  const FeedRightActionsColumn({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.onLike,
    required this.onVote,
    required this.averageRating,
    required this.voteCount,
    required this.hasVoted,
    required this.onComment,
    required this.onShare,
    required this.bottomPadding,
    this.likeScale = 1.0,
  });

  final String avatarUrl;
  final String username;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onVote;
  final double averageRating;
  final int voteCount;
  final bool hasVoted;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final double bottomPadding;

  /// Pop animation when like toggles (1.0 → brief bump).
  final double likeScale;

  static String _compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final initial = username.replaceFirst('@', '').trim();
    final letter = initial.isNotEmpty ? initial[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.only(right: 10, bottom: bottomPadding + 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AvatarRing(
            avatarUrl: avatarUrl,
            fallbackLetter: letter,
          ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: _compactCount(likeCount),
            iconColor: isLiked ? Colors.redAccent : Colors.white,
            scale: likeScale,
            onTap: onLike,
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: hasVoted ? Icons.star_rounded : Icons.star_outline_rounded,
            label: voteCount > 0
                ? '${averageRating.toStringAsFixed(1)} · ${_compactCount(voteCount)}'
                : I18n.inline('Оцінка', 'Vote'),
            iconColor: hasVoted ? const Color(0xFFFFC107) : Colors.white,
            onTap: onVote,
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.chat_bubble_rounded,
            label: _compactCount(commentCount),
            onTap: onComment,
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.avatarUrl, required this.fallbackLetter});

  final String avatarUrl;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(blurRadius: 8, color: Colors.black45),
        ],
      ),
      child: ClipOval(
        child: avatarUrl.isEmpty
            ? ColoredBox(
                color: Colors.white24,
                child: Center(
                  child: Text(
                    fallbackLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              )
            : Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: Colors.white24,
                  child: Center(
                    child: Text(
                      fallbackLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    this.scale = 1.0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: scale,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(blurRadius: 4, color: Colors.black87),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
