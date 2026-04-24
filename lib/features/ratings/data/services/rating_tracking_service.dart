import 'package:supabase_flutter/supabase_flutter.dart';

class RatingTrackingService {
  static final RatingTrackingService _instance = RatingTrackingService._internal();
  factory RatingTrackingService() => _instance;
  RatingTrackingService._internal();

  /// Logs a rating change for debugging. [user_rating_snapshots] rows for the
  /// ratee are written by [recompute_player_overall_rating] (SECURITY DEFINER);
  /// the client may not insert another user's snapshot under RLS.
  Future<void> recordRatingChange({
    required String userId,
    required double oldRating,
    required double newRating,
    required String reason,
    String? challengeTitle,
    String? voterName,
    String? challengeId,
    String? videoTitle,
  }) async {
    final change = newRating - oldRating;
    if (Supabase.instance.client.auth.currentUser != null) {
      print(
        '✅ Rating change ($userId): ${change > 0 ? '+' : ''}'
        '${change.toStringAsFixed(2)} ($reason)',
      );
    }
  }
}
