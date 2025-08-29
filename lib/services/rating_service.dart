import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class RatingService {
  static const double _matchWeight = 0.7; // 70% ваги для матчів
  static const double _videoWeight = 0.3; // 30% ваги для відео/челенджів
  static const double _defaultRating = 3.0; // Початковий рейтинг для нових користувачів

  // Критерії оцінювання для матчів
  static const List<String> _matchCriteria = [
    'technical',    // Техніка
    'physical',     // Фізика
    'tactical',     // Тактика
    'teamwork',     // Командна гра
  ];

  // Критерії оцінювання для відео
  static const List<String> _videoCriteria = [
    'technical',    // Технічне виконання (40%)
    'creativity',   // Креативність (30%)
    'difficulty',   // Складність (20%)
    'quality',      // Якість відео (10%)
  ];

  // Ваги для відео критеріїв
  static const Map<String, double> _videoWeights = {
    'technical': 0.4,
    'creativity': 0.3,
    'difficulty': 0.2,
    'quality': 0.1,
  };

  // Отримати поточний рейтинг користувача
  Future<double> getUserRating(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final rating = data['rating'];
        
        // Якщо рейтинг відсутній або 0.0/некоректний, встановлюємо початковий
        if (rating == null || (rating is num && rating <= 0.0)) {
          await _initializeUserRating(userId);
          return _defaultRating;
        }
        
        return (rating as num).toDouble();
      } else {
        // Користувача не існує, створюємо з початковим рейтингом
        await _initializeUserRating(userId);
        return _defaultRating;
      }
    } catch (e) {
      print('Error getting user rating: $e');
      return _defaultRating;
    }
  }

  // Ініціалізувати користувача з початковим рейтингом
  Future<void> _initializeUserRating(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'rating': _defaultRating,
        'matchRating': _defaultRating,
        'videoRating': _defaultRating,
        'totalMatches': 0,
        'totalVideos': 0,
        'ratingHistory': [],
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error initializing user rating: $e');
    }
  }

  // Отримати детальну статистику рейтингу
  Future<Map<String, dynamic>> getUserRatingStats(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'currentRating': (data['rating'] ?? _defaultRating).toDouble(),
          'matchRating': (data['matchRating'] ?? _defaultRating).toDouble(),
          'videoRating': (data['videoRating'] ?? _defaultRating).toDouble(),
          'totalMatches': (data['totalMatches'] ?? 0).toInt(),
          'totalVideos': (data['totalVideos'] ?? 0).toInt(),
          'ratingHistory': List<Map<String, dynamic>>.from(data['ratingHistory'] ?? []),
        };
      }
      return {};
    } catch (e) {
      print('Error getting user rating stats: $e');
      return {};
    }
  }

  // Оцінити гравця після матчу
  Future<bool> ratePlayerAfterMatch({
    required String matchId,
    required String playerId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) async {
    try {
      // Перевірка чи не оцінює сам себе
      if (playerId == ratedBy) {
        throw Exception('Не можна оцінювати самого себе');
      }

      // Валідація критеріїв
      for (final criterion in _matchCriteria) {
        if (!criteria.containsKey(criterion)) {
          throw Exception('Відсутній критерій: $criterion');
        }
        if (criteria[criterion]! < 0.0 || criteria[criterion]! > 5.0) {
          throw Exception('Оцінка має бути від 0.0 до 5.0');
        }
      }

      // Розрахунок середньої оцінки
      double totalRating = 0.0;
      for (final criterion in _matchCriteria) {
        totalRating += criteria[criterion]!;
      }
      final averageRating = totalRating / _matchCriteria.length;

      // Збереження оцінки в матчі
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('playerRatings')
          .doc('${playerId}_${ratedBy}')
          .set({
        'playerId': playerId,
        'ratedBy': ratedBy,
        'rating': averageRating,
        'criteria': criteria,
        'ratedAt': FieldValue.serverTimestamp(),
        'matchId': matchId,
      });

      // Оновлення рейтингу гравця
      await _updatePlayerRating(
        playerId,
        reason: 'Оцінка після матчу',
        source: 'Система матчів',
        sourceType: 'match',
        sourceId: matchId,
      );

      return true;
    } catch (e) {
      print('Error rating player after match: $e');
      return false;
    }
  }

  // Оцінити відео
  Future<bool> rateVideo({
    required String videoId,
    required String ratedBy,
    required Map<String, double> criteria,
  }) async {
    try {
      // Валідація критеріїв
      for (final criterion in _videoCriteria) {
        if (!criteria.containsKey(criterion)) {
          throw Exception('Відсутній критерій: $criterion');
        }
        if (criteria[criterion]! < 0.0 || criteria[criterion]! > 5.0) {
          throw Exception('Оцінка має бути від 0.0 до 5.0');
        }
      }

      // Розрахунок зваженої оцінки
      double weightedRating = 0.0;
      for (final criterion in _videoCriteria) {
        weightedRating += criteria[criterion]! * _videoWeights[criterion]!;
      }

      // Збереження оцінки відео
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('votes')
          .doc(ratedBy)
          .set({
        'ratedBy': ratedBy,
        'rating': weightedRating,
        'criteria': criteria,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // Отримуємо автора відео для оновлення його рейтингу
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (videoDoc.exists) {
        final videoData = videoDoc.data()!;
        final authorId = videoData['userId'] as String?;
        
        if (authorId != null && authorId != ratedBy) {
          // Отримуємо ім'я того, хто оцінив відео
          String voterName = 'Користувач';
          try {
            final voterDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(ratedBy)
                .get();
            if (voterDoc.exists) {
              final v = voterDoc.data() as Map<String, dynamic>;
              final emailPrefix = FirebaseAuth.instance.currentUser?.email?.split('@')[0];
              voterName = (v['displayName'] ?? v['authorName'] ?? v['name'] ??
                      (v['firstName'] != null || v['lastName'] != null
                          ? '${v['firstName'] ?? ''} ${v['lastName'] ?? ''}'.trim()
                          : null) ??
                      emailPrefix ??
                      'Користувач')
                  .toString();
            }
          } catch (_) {}

          // Оновлюємо рейтинг автора відео і зберігаємо нотифікацію
          await _updatePlayerRating(
            authorId,
            reason: 'Оцінка відео ${weightedRating.toStringAsFixed(1)}',
            source: voterName,
            sourceType: 'video',
            sourceId: videoId,
          );
        }
      }

      return true;
    } catch (e) {
      print('Error rating video: $e');
      return false;
    }
  }

  // Оновити загальний рейтинг гравця
  Future<void> _updatePlayerRating(String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  }) async {
    try {
      // Отримуємо поточний рейтинг користувача
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final currentData = userDoc.data()!;
      final oldRating = (currentData['rating'] ?? _defaultRating).toDouble();
      
      // Отримуємо всі оцінки з матчів
      final matchRatings = await _getMatchRatings(userId);
      
      // Отримуємо всі оцінки з відео
      final videoRatings = await _getVideoRatings(userId);

      // Розрахунок середнього рейтингу матчів
      double matchRating = _defaultRating; // Початковий рейтинг за замовчуванням
      if (matchRatings.isNotEmpty) {
        double total = 0.0;
        for (final rating in matchRatings) {
          total += rating;
        }
        matchRating = total / matchRatings.length;
      }

      // Розрахунок середнього рейтингу відео
      double videoRating = _defaultRating; // Початковий рейтинг за замовчуванням
      if (videoRatings.isNotEmpty) {
        double total = 0.0;
        for (final rating in videoRatings) {
          total += rating;
        }
        videoRating = total / videoRatings.length;
      }

      // Розрахунок загального рейтингу з вагами
      double overallRating = (matchRating * _matchWeight) + (videoRating * _videoWeight);

      // Оновлення рейтингу користувача
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'rating': double.parse(overallRating.toStringAsFixed(2)),
        'matchRating': double.parse(matchRating.toStringAsFixed(2)),
        'videoRating': double.parse(videoRating.toStringAsFixed(2)),
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });

      // Додавання в історію рейтингу
      await _addRatingHistory(userId, overallRating, matchRating, videoRating);

      // Відправка сповіщення про зміну рейтингу
      if (reason != null && source != null && sourceType != null) {
        final notificationService = NotificationService();
        await notificationService.sendCoinsEarnedNotification(
          toUserId: userId,
          amount: 0, // Це не про монети, але використовуємо наявний метод
          reason: 'Рейтинг оновлено: $reason',
        );
      }

    } catch (e) {
      print('Error updating player rating: $e');
    }
  }

  // Отримати всі оцінки гравця з матчів
  Future<List<double>> _getMatchRatings(String userId) async {
    try {
      final ratings = <double>[];
      
      // Шукаємо всі матчі, де гравець брав участь
      final matchesQuery = await FirebaseFirestore.instance
          .collection('matches')
          .where('status', isEqualTo: 'finished')
          .get();

      for (final matchDoc in matchesQuery.docs) {
        final ratingsQuery = await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchDoc.id)
            .collection('playerRatings')
            .where('playerId', isEqualTo: userId)
            .get();

        for (final ratingDoc in ratingsQuery.docs) {
          final data = ratingDoc.data();
          ratings.add((data['rating'] ?? 0.0).toDouble());
        }
      }

      return ratings;
    } catch (e) {
      print('Error getting match ratings: $e');
      return [];
    }
  }

  // Отримати всі оцінки гравця з відео
  Future<List<double>> _getVideoRatings(String userId) async {
    try {
      final ratings = <double>[];
      
      // Шукаємо всі відео автора
      final videosQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .get();

      for (final videoDoc in videosQuery.docs) {
        final votesQuery = await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoDoc.id)
            .collection('votes')
            .get();

        for (final voteDoc in votesQuery.docs) {
          final data = voteDoc.data() as Map<String, dynamic>?;
          if (data != null) {
            ratings.add((data['rating'] ?? 0.0).toDouble());
          }
        }
      }

      return ratings;
    } catch (e) {
      print('Error getting video ratings: $e');
      return [];
    }
  }

  // Додати в історію рейтингу
  Future<void> _addRatingHistory(String userId, double overallRating, double matchRating, double videoRating) async {
    try {
      final historyEntry = {
        'overallRating': overallRating,
        'matchRating': matchRating,
        'videoRating': videoRating,
        // Avoid serverTimestamp inside arrayUnion due to Firestore limitation
        'timestamp': Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'ratingHistory': FieldValue.arrayUnion([historyEntry]),
      });

      // Обмежуємо історію до останніх 30 записів
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final history = List<Map<String, dynamic>>.from(data['ratingHistory'] ?? []);
        
        if (history.length > 30) {
          // Залишаємо тільки останні 30 записів
          final trimmedHistory = history.sublist(history.length - 30);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'ratingHistory': trimmedHistory,
          });
        }
      }
    } catch (e) {
      print('Error adding rating history: $e');
    }
  }

  // Отримати топ гравців за рейтингом
  Future<List<Map<String, dynamic>>> getTopPlayers({
    int limit = 10,
    String? city,
    String? position,
  }) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('rating', isGreaterThan: _defaultRating - 0.1) // Виключаємо тих, хто не має рейтингу
          .orderBy('rating', descending: true)
          .limit(limit);

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      if (position != null && position.isNotEmpty) {
        query = query.where('position', isEqualTo: position);
      }

      final snapshot = await query.get();
      final players = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        players.add({
          'id': doc.id,
          'name': data['displayName'] ?? 'Невідомий',
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'city': data['city'] ?? 'Невідомо',
          'position': data['position'] ?? 'Невідомо',
          'totalMatches': data['totalMatches'] ?? 0,
          'avatarUrl': data['avatarUrl'],
        });
      }

      return players;
    } catch (e) {
      print('Error getting top players: $e');
      return [];
    }
  }

  // Отримати рівень гравця за рейтингом
  String getPlayerLevel(double rating) {
    if (rating >= 0.0 && rating < 1.5) return 'Новачок';
    if (rating >= 1.5 && rating < 2.5) return 'Початковий';
    if (rating >= 2.5 && rating < 3.5) return 'Середній';
    if (rating >= 3.5 && rating < 4.5) return 'Високий';
    if (rating >= 4.5 && rating <= 5.0) return 'Професійний';
    return 'Невідомо';
  }

  // Отримати кольір рівня
  int getPlayerLevelColor(double rating) {
    if (rating >= 0.0 && rating < 1.5) return 0xFF9E9E9E; // Сірий
    if (rating >= 1.5 && rating < 2.5) return 0xFF4CAF50; // Зелений
    if (rating >= 2.5 && rating < 3.5) return 0xFF2196F3; // Синій
    if (rating >= 3.5 && rating < 4.5) return 0xFFFF9800; // Помаранчевий
    if (rating >= 4.5 && rating <= 5.0) return 0xFF9C27B0; // Фіолетовий
    return 0xFF9E9E9E; // Сірий за замовчуванням
  }

  // Створити користувача з початковим рейтингом
  Future<void> createUserWithDefaultRating(String userId, Map<String, dynamic> userData) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        ...userData,
        'rating': _defaultRating,
        'matchRating': _defaultRating,
        'videoRating': _defaultRating,
        'totalMatches': 0,
        'totalVideos': 0,
        'ratingHistory': [],
        'createdAt': FieldValue.serverTimestamp(),
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user with default rating: $e');
    }
  }

  // Отримати початковий рейтинг
  double getDefaultRating() => _defaultRating;
    // Отримати рейтинг матчу
  Stream<double> getMatchRating(String matchId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        // Тут можна додати логіку розрахунку рейтингу матчу
        return 0.0; // Тимчасово повертаємо 0.0
      }
      return 0.0;
    });
  }
}
