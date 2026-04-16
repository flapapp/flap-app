import 'package:flutter/material.dart';

import 'package:flap_app/core/media/flap_cached_image.dart';

/// Reusable avatar button that routes to the player profile by default.
class PlayerAvatarButton extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final double size;
  final Color backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const PlayerAvatarButton({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.size = 32,
    this.backgroundColor = const Color(0xFF4caf50),
    this.borderColor,
    this.borderWidth = 0,
    this.onTap,
  });

  void _defaultNavigate(BuildContext context) {
    if (userId.isEmpty) return;
    Navigator.pushNamed(
      context,
      '/player-profile',
      arguments: {
        'playerId': userId,
        'playerName': displayName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallback = (displayName.isNotEmpty
            ? displayName[0]
            : userId.isNotEmpty
                ? userId[0]
                : 'U')
        .toUpperCase();
    final normalizedAvatarUrl = avatarUrl?.trim() ?? '';
    final hasAvatar =
        normalizedAvatarUrl.isNotEmpty &&
        (normalizedAvatarUrl.startsWith('http://') ||
            normalizedAvatarUrl.startsWith('https://'));

    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            fallback,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.45,
            ),
          ),
          if (hasAvatar)
            ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: FlapCachedImage(
                  imageUrl: normalizedAvatarUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );

    if (borderColor != null && borderWidth > 0) {
      avatar = Container(
        width: size + borderWidth * 2,
        height: size + borderWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatar,
      );
    }

    return GestureDetector(
      onTap: () => (onTap ?? () => _defaultNavigate(context))(),
      child: avatar,
    );
  }
}








