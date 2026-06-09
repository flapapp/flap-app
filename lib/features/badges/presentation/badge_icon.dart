import 'package:flutter/material.dart';

/// Maps a badge's stored emoji glyph (from the DB) to a Material icon, so the
/// app renders icons instead of emojis. Falls back to a generic award icon for
/// any unmapped glyph.
IconData flapBadgeIcon(String? emoji) {
  switch ((emoji ?? '').trim()) {
    case '🏆':
      return Icons.emoji_events_rounded;
    case '🥇':
    case '🥈':
    case '🥉':
    case '🏅':
    case '🎖️':
      return Icons.military_tech_rounded;
    case '⭐':
    case '🌟':
      return Icons.star_rounded;
    case '✨':
      return Icons.auto_awesome_rounded;
    case '⚽':
      return Icons.sports_soccer_rounded;
    case '🧤':
      return Icons.back_hand_rounded;
    case '🎯':
      return Icons.gps_fixed_rounded;
    case '📡':
      return Icons.podcasts_rounded;
    case '🛡️':
      return Icons.shield_rounded;
    case '🧱':
      return Icons.fence_rounded;
    case '🌀':
      return Icons.cyclone_rounded;
    case '🧠':
      return Icons.psychology_rounded;
    case '💥':
      return Icons.bolt_rounded;
    case '⚡':
      return Icons.flash_on_rounded;
    case '🔥':
      return Icons.local_fire_department_rounded;
    case '💪':
      return Icons.fitness_center_rounded;
    case '👟':
    case '🥾':
      return Icons.directions_run_rounded;
    case '🏃':
      return Icons.directions_run_rounded;
    case '👑':
      return Icons.workspace_premium_rounded;
    case '💎':
      return Icons.diamond_rounded;
    case '🚀':
      return Icons.rocket_launch_rounded;
    case '🎓':
      return Icons.school_rounded;
    case '🎲':
      return Icons.casino_rounded;
    case '🧙':
      return Icons.auto_fix_high_rounded;
    case '🦅':
      return Icons.flight_rounded;
    case '🦁':
    case '🐉':
      return Icons.pets_rounded;
    case '🎮':
      return Icons.sports_esports_rounded;
    case '🏟️':
      return Icons.stadium_rounded;
    case '🤝':
      return Icons.handshake_rounded;
    case '👍':
      return Icons.thumb_up_rounded;
    case '💰':
      return Icons.monetization_on_rounded;
    default:
      return Icons.workspace_premium_rounded;
  }
}
