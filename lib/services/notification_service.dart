import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static const String _collection = 'notifications';

  // Показати сповіщення про зміну рейтингу
  static void showRatingChangeNotification(
    BuildContext context, {
    required double oldRating,
    required double newRating,
    required String reason,
    required String source,
  }) {
    final change = newRating - oldRating;
    final changeText = change >= 0 ? '+${change.toStringAsFixed(1)}' : change.toStringAsFixed(1);
    final changeColor = change >= 0 ? Colors.green : Colors.red;
    final changeIcon = change >= 0 ? '📈' : '📉';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(changeIcon, style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Рейтинг змінився: $changeText',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Причина: $reason від $source',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: changeColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Деталі',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Перехід до деталей рейтингу
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Зберегти сповіщення в базі даних
  static Future<void> saveRatingNotification({
    required String userId,
    required double oldRating,
    required double newRating,
    required String reason,
    required String source,
    required String sourceType, // 'video', 'match'
    String? sourceId,
  }) async {
    try {
      final change = newRating - oldRating;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .add({
        'type': 'rating_change',
        'oldRating': oldRating,
        'newRating': newRating,
        'change': change,
        'reason': reason,
        'source': source,
        'sourceType': sourceType,
        'sourceId': sourceId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('Error saving rating notification: $e');
    }
  }

  // Отримати сповіщення користувача
  static Stream<List<Map<String, dynamic>>> getUserNotifications(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'createdAt': data['createdAt'] as Timestamp?,
        };
      }).toList();
    });
  }

  // Позначити сповіщення як прочитане
  static Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Отримати кількість непрочитаних сповіщень
  static Stream<int> getUnreadNotificationsCount(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_collection)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Видалити старі сповіщення (старше 30 днів)
  static Future<void> cleanupOldNotifications(String userId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final oldNotifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_collection)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }
}
