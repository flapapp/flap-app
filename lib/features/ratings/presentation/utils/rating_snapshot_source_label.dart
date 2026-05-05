import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Match, video, or challenge activity only — hide recompute, legacy sync, manual, unknown.
bool ratingHistoryIsPublicTriggerSource(String? raw) {
  const allowed = <String>{
    'match_rating',
    'video_rating',
    'challenge_submission_rating',
  };
  return allowed.contains((raw ?? '').trim());
}

/// Accent for source badge / chips (match vs video vs challenge).
Color ratingSnapshotSourceAccentColor(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'match_rating':
      return const Color(0xFF42A5F5);
    case 'video_rating':
      return const Color(0xFFBA68C8);
    case 'challenge_submission_rating':
      return const Color(0xFFFFB74D);
    case 'legacy_video_sync':
      return const Color(0xFF78909C);
    case 'manual_recompute':
      return const Color(0xFF26A69A);
    default:
      return const Color(0xFF81C784);
  }
}

/// Short category title for chips/badges (match vs video vs challenge).
String ratingSnapshotSourceBadge(String? raw) {
  final s = (raw ?? '').trim();
  switch (s) {
    case 'match_rating':
      return tr('rating_history_badge_match');
    case 'video_rating':
      return tr('rating_history_badge_video');
    case 'challenge_submission_rating':
      return tr('rating_history_badge_challenge');
    case 'legacy_video_sync':
      return tr('rating_history_badge_legacy');
    case 'manual_recompute':
      return tr('rating_history_badge_manual');
    case 'recompute':
    case '':
      return tr('rating_history_badge_recompute');
    default:
      return tr('rating_history_badge_other');
  }
}

/// Maps [user_rating_snapshots.trigger_source] to a localized, explicit label.
String ratingSnapshotSourceLabel(String? raw) {
  final s = (raw ?? '').trim();
  switch (s) {
    case 'match_rating':
      return tr('rating_history_source_match');
    case 'video_rating':
      return tr('rating_history_source_video');
    case 'challenge_submission_rating':
      return tr('rating_history_source_challenge');
    case 'legacy_video_sync':
      return tr('rating_history_source_legacy');
    case 'manual_recompute':
      return tr('rating_history_source_manual');
    case 'recompute':
    case '':
      return tr('rating_history_source_recompute');
    default:
      return tr(
        'rating_history_source_other',
        namedArgs: {'source': s},
      );
    }
}
