import 'package:supabase_flutter/supabase_flutter.dart';

class RatingTrackingService {
  static final RatingTrackingService _instance = RatingTrackingService._internal();
  factory RatingTrackingService() => _instance;
  RatingTrackingService._internal();

  final SupabaseClient _sb = Supabase.instance.client;

  /// Записує зміну рейтингу в історію
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
    try {
      final change = newRating - oldRating;
      
      await _sb.from('user_rating_snapshots').insert({
        'user_id': userId,
        'rating_scope': 'overall',
        'rating_value': newRating,
      });

      print('✅ Rating change recorded: ${change > 0 ? '+' : ''}${change.toStringAsFixed(2)} ($reason)');
    } catch (e) {
      print('❌ Error recording rating change: $e');
    }
  }

  /// Оновлює рейтинг користувача та записує в історію
  Future<void> updateUserRating({
    required String userId,
    required double newRating,
    required String reason,
    String? challengeTitle,
    String? voterName,
    String? challengeId,
  }) async {
    try {
      final oldRating = await _loadCurrentRating(userId);

      // Записуємо в історію
      await recordRatingChange(
        userId: userId,
        oldRating: oldRating,
        newRating: newRating,
        reason: reason,
        challengeTitle: challengeTitle,
        voterName: voterName,
        challengeId: challengeId,
      );

      print('✅ User rating updated: $oldRating → $newRating');
    } catch (e) {
      print('❌ Error updating user rating: $e');
    }
  }

  Future<double> _loadCurrentRating(String userId) async {
    final row = await _sb
        .from('user_rating_snapshots')
        .select('rating_value')
        .eq('user_id', userId)
        .eq('rating_scope', 'overall')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return 0.0;
    final value = row['rating_value'];
    return (value is num) ? value.toDouble() : 0.0;
  }
}
