import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'rating_tracking_service.dart';

class RatingService {
  static const double _matchWeight = 0.7; // 70% ваги для матчів
  static const double _videoWeight = 0.3; // 30% ваги для відео/челенджів
  static const double _defaultRating = 3.0; // Початковий рейтинг для нових користувачів

// Нове: правила з Повної документації
  static const bool _trimOutliers = false; // тримінг вимкнено

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

  // Перерахунок середньої оцінки відео та збереження в полі videos.rating
  Future<void> updateVideoAggregate(String videoId) async {
    try {
      final votesSnap = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .collection('votes')
          .get();
      double sum = 0.0;
      for (final d in votesSnap.docs) {
        final m = d.data() as Map<String, dynamic>;
        sum += (m['rating'] ?? 0.0).toDouble();
      }
      final count = votesSnap.docs.length;
      final avg = count == 0 ? 0.0 : double.parse((sum / count).toStringAsFixed(2));
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'rating': avg,
        'voteCount': count,
      });
    } catch (e) {
      // non-fatal
    }
  }

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
  // не створюємо документ; просто повертаємо дефолт
  return _defaultRating;
}
        
        return (rating as num).toDouble();
      } else {
  // користувача немає — повертаємо дефолт без запису
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

            // Перевірка стану матчу та учасників
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();
      if (!matchDoc.exists) {
  throw Exception('Матч не знайдено');
}
final matchData = matchDoc.data() as Map<String, dynamic>;
if (matchData['status'] != 'finished') {
  throw Exception('Матч ще не завершено');
}
final participants = List<String>.from(matchData['participants'] ?? const <String>[]);
if (!participants.contains(ratedBy) || !participants.contains(playerId)) {
  throw Exception('Лише учасники можуть оцінювати');
}

// Нове: оцінювання лише всередині своєї команди (якщо команди задані)
final teamAIds = List<String>.from((matchData['teamA']?['playerIds']) ?? const <String>[]);
final teamBIds = List<String>.from((matchData['teamB']?['playerIds']) ?? const <String>[]);
final bool teamsExist = teamAIds.isNotEmpty || teamBIds.isNotEmpty;
if (teamsExist) {
  final sameTeam = (teamAIds.contains(ratedBy) && teamAIds.contains(playerId)) ||
                   (teamBIds.contains(ratedBy) && teamBIds.contains(playerId));
  if (!sameTeam) {
    throw Exception('Оцінювання дозволене лише гравцями своєї команди');
  }
}

      // Уникнення дублю (пара playerId_ratedBy)
      final ratingDocRef = FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('playerRatings')
          .doc('${playerId}_${ratedBy}');
      if ((await ratingDocRef.get()).exists) {
        throw Exception('Ви вже оцінювали цього гравця');
      }

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

      // Оновлюємо агрегати відео для відображення зірочки у списках
      await updateVideoAggregate(videoId);

      // Отримуємо автора відео для оновлення його рейтингу
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();

      if (videoDoc.exists) {
        final videoData = videoDoc.data()!;
        final authorId = videoData['userId'] as String?;
        final videoTitle = (videoData['title'] ?? 'Відео').toString();
        
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

          // Перед оновленням зчитуємо попередній рейтинг
          final beforeDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
          final oldRating = (beforeDoc.data()?['rating'] ?? _defaultRating).toDouble();

          // Оновлюємо рейтинг автора відео і зберігаємо нотифікацію
          await _updatePlayerRating(
            authorId,
            reason: 'Оцінка відео ${weightedRating.toStringAsFixed(1)}',
            source: voterName,
            sourceType: 'video',
            sourceId: videoId,
          );

          // Відправляємо нотифікації: про голос та про зміну рейтингу
          try {
            // 1) Нотифікація про голос з конкретною оцінкою
            await NotificationService().sendVideoVoteNotification(
              toUserId: authorId,
              videoTitle: videoTitle,
              voterName: voterName,
              rating: weightedRating,
            );

            // 2) Нотифікація про зміну рейтингу (дельта і нове значення)
            final afterDoc = await FirebaseFirestore.instance.collection('users').doc(authorId).get();
            final newRating = (afterDoc.data()?['rating'] ?? _defaultRating).toDouble();
            final delta = newRating - oldRating;
            await NotificationService().sendRatingChangedNotification(
              toUserId: authorId,
              voterName: voterName,
              rating: weightedRating,
              delta: delta,
              newRating: newRating,
              videoTitle: videoTitle,
            );
          } catch (_) {}
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

      // Дублюємо запис у публічну колекцію rating_history для відображення в модалці
      try {
        if (reason != null) {
          String? challengeTitle;
          if (sourceType == 'challenge' && sourceId != null && sourceId!.isNotEmpty) {
            try {
              final ch = await FirebaseFirestore.instance.collection('challenges').doc(sourceId).get();
              if (ch.exists) {
                final cd = ch.data() as Map<String, dynamic>;
                challengeTitle = (cd['title'] ?? '').toString();
              }
            } catch (_) {}
          }
          await RatingTrackingService().recordRatingChange(
            userId: userId,
            oldRating: double.parse(oldRating.toStringAsFixed(2)),
            newRating: double.parse(overallRating.toStringAsFixed(2)),
            reason: reason,
            challengeTitle: challengeTitle,
            voterName: source,
            challengeId: sourceType == 'challenge' ? sourceId : null,
            videoTitle: sourceType == 'video' ? sourceId : null,
          );
        }
      } catch (_) {}

      // Відправка сповіщення про зміну рейтингу — для challenge_vote надсилаємо окремо в місці голосу
      if (reason != null && source != null && reason != 'challenge_vote') {
        final newRatingRounded = double.parse(overallRating.toStringAsFixed(2));
        final delta = double.parse((newRatingRounded - oldRating).toStringAsFixed(2));
        await NotificationService().sendRatingChangedNotification(
          toUserId: userId,
          voterName: source,
          rating: 0.0, // не завжди відомо; для відео додаємо окремо у rateVideo
          delta: delta,
          newRating: newRatingRounded,
          videoTitle: sourceType == 'video' ? (sourceId ?? '') : null,
        );
      }

    } catch (e) {
      print('Error updating player rating: $e');
    }
  }

  // Отримати всі оцінки гравця з матчів
    Future<List<double>> _getMatchRatings(String userId) async {
  try {
    print('📊 _getMatchRatings for userId=$userId');
    final perMatchAverages = <double>[];

    // Беремо всі завершені матчі
    final matchesQuery = await FirebaseFirestore.instance
    .collection('matches')
    .where('status', isEqualTo: 'finished')
    .where('participants', arrayContains: userId) // лише матчі, де гравець брав участь
    .get();
    
    print('📊 Found ${matchesQuery.docs.length} finished matches');

    for (final matchDoc in matchesQuery.docs) {
      // У цьому матчі всі оцінки для userId
      final ratingsQuery = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchDoc.id)
          .collection('playerRatings')
          .where('playerId', isEqualTo: userId)
          .get();

      final values = <double>[];
      for (final d in ratingsQuery.docs) {
        final m = d.data();
        values.add((m['rating'] ?? 0.0).toDouble());
      }

      print('📊 Match ${matchDoc.id}: got ${values.length} ratings for userId');
      print('📊 Match ${matchDoc.id}: got ${values.length} ratings for userId');
      print('   Ratings: ${values.map((v) => v.toStringAsFixed(2)).join(', ')}');

      // Тримінг вимкнено: використовуємо всі значення як є
      if (values.isEmpty) {
          continue;
        }

      final trimmed = values;

      final avg = trimmed.reduce((a, b) => a + b) / trimmed.length;
      perMatchAverages.add(double.parse(avg.toStringAsFixed(2)));
    }

    return perMatchAverages;
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
    int limit = 50,
    String? city,
    String? position,
  }) async {
    try {
      // Беремо всіх користувачів без where-фільтрів (клієнтська фільтрація)
      final snapshot = await FirebaseFirestore.instance.collection('users').limit(500).get();
      final allPlayers = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final rating = (data['rating'] ?? 0.0).toDouble();
        final totalMatches = (data['totalMatches'] ?? data['matches'] ?? data['matchesPlayed'] ?? 0) as int;
        final totalVideos = (data['totalVideos'] ?? 0) as int;
        final userCity = (data['city'] ?? '').toString();
        final userPosition = (data['position'] ?? '').toString();
        
        // Клієнтська фільтрація по місту
        if (city != null && city.isNotEmpty && city != 'Всі міста') {
          if (userCity != city) continue;
        }
        
        // Клієнтська фільтрація по позиції
        if (position != null && position.isNotEmpty && position != 'Всі позиції') {
          if (userPosition != position) continue;
        }
        
        allPlayers.add({
          'id': doc.id,
          'name': data['displayName'] ?? data['name'] ?? data['authorName'] ?? data['email']?.toString().split('@').first ?? 'Невідомий',
          'rating': rating,
          'city': userCity.isNotEmpty ? userCity : 'Невідомо',
          'position': userPosition.isNotEmpty ? userPosition : 'Невідомо',
          'totalMatches': totalMatches,
          'totalVideos': totalVideos,
          'avatarUrl': data['avatarUrl'] ?? data['avatar'] ?? data['photoUrl'] ?? data['photoURL'] ?? '',
        });
      }
      
      // Сортуємо по рейтингу на клієнті
      allPlayers.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
      
      // Повертаємо топ N
      return allPlayers.take(limit).toList();
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
  // Отримати рейтинг матчу (середнє оцінок з matches/{matchId}/playerRatings)
Stream<double> getMatchRating(String matchId) {
  return FirebaseFirestore.instance
      .collection('matches')
      .doc(matchId)
      .collection('playerRatings')
      .snapshots()
      .map((snap) {
        if (!snap.docs.any((_) => true)) return 0.0;

        final ratings = <double>[];
        for (final d in snap.docs) {
          final m = d.data() as Map<String, dynamic>;
          final r = (m['rating'] ?? 0.0);
          if (r is num) ratings.add(r.toDouble());
        }
        if (ratings.isEmpty) return 0.0;

        ratings.sort();
        final effective = ratings; // без тримінгу

        final avg = effective.reduce((a, b) => a + b) / effective.length;
        return double.parse(avg.toStringAsFixed(2));
      });
}

  // Публічний метод для перерахунку загального рейтингу (використовується з челенджів)
  Future<void> recomputeOverallRating(
    String userId, {
    String? reason,
    String? source,
    String? sourceType,
    String? sourceId,
  }) async {
    await _updatePlayerRating(
      userId,
      reason: reason,
      source: source,
      sourceType: sourceType,
      sourceId: sourceId,
    );
  }

  // Ручний перерахунок для всіх учасників конкретного матчу
Future<void> recomputeForMatchParticipants(String matchId) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final participants = List<String>.from(data['participants'] ?? const <String>[]);
    for (final uid in participants.toSet()) {
      await recomputeOverallRating(
        uid,
        reason: 'manual_recompute',
        source: 'Адмін',
        sourceType: 'system',
        sourceId: matchId,
      );
    }
  } catch (_) {}
}

// Масовий перерахунок для всіх користувачів (обережно на продакшені)
Future<void> recomputeAllUsers({int pageSize = 200}) async {
  try {
    Query q = FirebaseFirestore.instance.collection('users').orderBy(FieldPath.documentId);
    DocumentSnapshot? last;
    while (true) {
      final snap = await (last == null ? q.limit(pageSize).get() : q.startAfterDocument(last!).limit(pageSize).get());
      if (snap.docs.isEmpty) break;
      for (final d in snap.docs) {
        await recomputeOverallRating(
          d.id,
          reason: 'manual_recompute',
          source: 'Адмін',
          sourceType: 'system',
          sourceId: 'bulk',
        );
      }
      last = snap.docs.last;
    }
  } catch (_) {}
}
}
