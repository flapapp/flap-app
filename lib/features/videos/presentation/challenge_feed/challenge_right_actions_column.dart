import 'package:flutter/material.dart';

import 'package:flap_app/core/media/flap_cached_image.dart';
import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/utils/i18n.dart';

/// Right rail for challenge feed (mirrors video feed layout; details replaces star vote).
class ChallengeRightActionsColumn extends StatelessWidget {
  const ChallengeRightActionsColumn({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.onInfo,
    required this.onJoin,
    required this.onShare,
    required this.bottomPadding,
    this.joinEnabled = true,
  });

  final String avatarUrl;
  final String username;
  final VoidCallback onInfo;
  final VoidCallback onJoin;
  final VoidCallback onShare;
  final double bottomPadding;
  final bool joinEnabled;

  @override
  Widget build(BuildContext context) {
    final initial = username.replaceFirst('@', '').trim();
    final letter = initial.isNotEmpty ? initial[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.only(right: 10, bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AvatarRing(avatarUrl: avatarUrl, fallbackLetter: letter),
          const SizedBox(height: 18),
          _ActionButton(
            icon: Icons.info_outline_rounded,
            label: I18n.inline('Деталі', 'Details'),
            iconColor: FlapTheme.accentSecondary,
            onTap: onInfo,
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.video_call_rounded,
            label: I18n.inline('Участь', 'Join'),
            iconColor: joinEnabled ? FlapTheme.accent : FlapTheme.onDarkMuted,
            onTap: joinEnabled ? onJoin : () {},
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.share_rounded,
            label: I18n.inline('Поділитися', 'Share'),
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
            : FlapCachedImage(
                imageUrl: avatarUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
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
