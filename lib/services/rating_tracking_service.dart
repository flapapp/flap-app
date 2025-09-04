import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingTrackingService {
  static final RatingTrackingService _instance = RatingTrackingService._internal();
  factory RatingTrackingService() => _instance;
  RatingTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      
      await _firestore.collection('rating_history').add({
        'userId': userId,
        'change': change,
        'oldRating': oldRating,
        'newRating': newRating,
        'reason': reason,
        'challengeTitle': challengeTitle ?? '',
        'voterName': voterName ?? '',
        'challengeId': challengeId ?? '',
        'videoTitle': videoTitle ?? '',
        'timestamp': FieldValue.serverTimestamp(),
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
      // Отримуємо поточний рейтинг
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final oldRating = (userData['rating'] ?? 0.0).toDouble();

      // Оновлюємо рейтинг
      await _firestore.collection('users').doc(userId).update({
        'rating': newRating,
      });

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
}
