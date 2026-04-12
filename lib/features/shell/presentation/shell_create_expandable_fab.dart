import 'package:flutter/material.dart';

import 'package:flap_app/core/theme/flap_theme.dart';
import 'package:flap_app/utils/i18n.dart';

/// Centered main FAB; first tap expands [onVideo]/[onChallenge]/[onMatch]/[onTeam] above it.
///
/// When [includeMainButton] is false, only the satellite actions are built when [expanded]
/// is true (for use with a create control in the bottom bar).
class ShellCreateExpandableFab extends StatelessWidget {
  const ShellCreateExpandableFab({
    super.key,
    this.includeMainButton = true,
    required this.expanded,
    required this.onToggle,
    required this.onVideo,
    required this.onChallenge,
    required this.onMatch,
    required this.onTeam,
  });

  /// When false, [onToggle] is unused; show only expanded sub-actions.
  final bool includeMainButton;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onVideo;
  final VoidCallback onChallenge;
  final VoidCallback onMatch;
  final VoidCallback onTeam;

  static const double _mainSize = 50;
  static const double _subSize = 48;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (expanded) ...[
            _SubAction(
              icon: Icons.videocam_outlined,
              background: const Color(0xFFFF6B35),
              tooltip: I18n.t('upload_video'),
              onTap: onVideo,
            ),
            const SizedBox(height: 10),
            _SubAction(
              icon: Icons.emoji_events_outlined,
              background: const Color(0xFFFFC107),
              tooltip: I18n.t('create_challenge'),
              onTap: onChallenge,
            ),
            const SizedBox(height: 10),
            _SubAction(
              icon: Icons.sports_soccer_rounded,
              background: const Color(0xFF2EE6A6),
              tooltip: I18n.inline('Новий матч', 'New match'),
              onTap: onMatch,
            ),
            const SizedBox(height: 10),
            _SubAction(
              icon: Icons.groups_rounded,
              background: const Color(0xFF5B8DEF),
              tooltip: I18n.inline('Нова команда', 'New team'),
              onTap: onTeam,
            ),
            if (includeMainButton) const SizedBox(height: 14),
          ],
          if (includeMainButton)
            Tooltip(
              message: expanded
                  ? I18n.inline('Закрити', 'Close')
                  : I18n.inline('Створити', 'Create'),
              child: GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: _mainSize,
                  height: _mainSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: expanded
                          ? [FlapTheme.surfaceElevated, FlapTheme.surface]
                          : const [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (expanded ? FlapTheme.accent : const Color(0xFFFF6B35))
                            .withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    expanded ? Icons.close_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubAction extends StatelessWidget {
  const _SubAction({
    required this.icon,
    required this.background,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color background;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: ShellCreateExpandableFab._subSize,
            height: ShellCreateExpandableFab._subSize,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
