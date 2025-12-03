import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/challenge.dart';
import '../models/notification.dart';
import 'notification_service.dart';
import '../utils/i18n.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Колекція челенджів
  CollectionReference get _challengesCollection => 
      _firestore.collection('challenges');

  // Отримати всі активні челенджі
  Stream<List<Challenge>> getActiveChallenges() {
    return _challengesCollection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList());
  }

  // Отримати челенджі за статусом
  Stream<List<Challenge>> getChallengesByStatus(ChallengeStatus status) {
    return _challengesCollection
        .where('isActive', isEqualTo: true)
        .where('status', isEqualTo: status.toString().split('.').last)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList());
  }

  // Отримати челенджі за містом
  Stream<List<Challenge>> getChallengesByCity(String city) {
    return _challengesCollection
        .where('isActive', isEqualTo: true)
        .where('city', isEqualTo: city)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList());
  }

  // Отримати челенджі за типом
  Stream<List<Challenge>> getChallengesByType(ChallengeType type) {
    return _challengesCollection
        .where('isActive', isEqualTo: true)
        .where('type', isEqualTo: challengeTypeToSlug(type))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList());
  }

  // Отримати конкретний челендж
  Future<Challenge?> getChallenge(String challengeId) async {
    try {
      final doc = await _challengesCollection.doc(challengeId).get();
      if (doc.exists) {
        return Challenge.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting challenge: $e');
      return null;
    }
  }

  // Створити новий челендж
  Future<String?> createChallenge(Challenge challenge) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Перевірка ліміту челенджів для користувача
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final maxChallenges = userData?['maxChallengesPerMonth'] ?? 1;
      final isSubscriptionActive = userData?['subscriptionActive'] ?? false;
      
      if (!isSubscriptionActive) {
        final userChallenges = await _challengesCollection
            .where('creatorId', isEqualTo: currentUser.uid)
            .get();
        final recentChallenges = userChallenges.docs.where((doc) {
          final c = Challenge.fromFirestore(doc);
          return c.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 30)));
        }).toList();
        if (recentChallenges.length >= maxChallenges) {
          throw Exception('Ліміт: $maxChallenges челендж на місяць. Оформіть підписку для необмежених челенджів!');
        }
      }

      // Списуємо вступну плату з творця і формуємо стартовий банк
      final entryFee = challenge.entryFee;
      await _firestore.runTransaction((tx) async {
        final userRef = _firestore.collection('users').doc(currentUser.uid);
        final userSnap = await tx.get(userRef);
        final coins = (userSnap.data()?['coins'] ?? 0) as int;
        if (coins < entryFee) {
          throw Exception('Недостатньо монет для створення челенджу');
        }
        tx.update(userRef, {'coins': FieldValue.increment(-entryFee)});
      });

      // Створюємо челендж зі стартовим prizePool = entryFee (внесок творця)
      final docRef = await _challengesCollection.add({
        ...challenge.toFirestore(),
        'prizePool': entryFee.toDouble(),
      });
      final challengeId = docRef.id;

      // Записуємо транзакцію списання для творця
      await _firestore.collection('transactions').add({
        'userId': currentUser.uid,
        'type': 'challenge_create_fee',
        'amount': -entryFee,
        'challengeId': challengeId,
        'challengeTitle': challenge.title,
        'timestamp': FieldValue.serverTimestamp(),
        'description': I18n.inline(
  'Плата за створення челенджу: ${challenge.title}',
  'Challenge creation fee: ${challenge.title}',
),
      });

      // Відправити нотифікації залежно від аудиторії
      await _sendChallengeInvitations(challengeId, challenge);

      return challengeId;
    } catch (e) {
      print('Error creating challenge: $e');
      rethrow;
    }
  }

  // Приєднатися до челенджу
  Future<bool> joinChallenge(String challengeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeRef = _challengesCollection.doc(challengeId);
      
      // Перевірка чи можна приєднатися
      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (!challenge.canJoin) {
        throw Exception('Не можна приєднатися до цього челенджу');
      }

      // Перевірка чи користувач вже учасник
      if (challenge.participants.contains(currentUser.uid)) {
        throw Exception('Ви вже учасник цього челенджу');
      }

      // Перевірити чи достатньо монет
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('Дані користувача не знайдено');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userCoins = userData['coins'] ?? 0;

      if (userCoins < challenge.entryFee) {
        throw Exception('Недостатньо монет! Потрібно: ${challenge.entryFee}, у вас: $userCoins');
      }

      // Виконати транзакцію
      await _firestore.runTransaction((transaction) async {
        // Додати учасника
        transaction.update(challengeRef, {
          'participants': FieldValue.arrayUnion([currentUser.uid]),
          'currentParticipants': FieldValue.increment(1),
          'prizePool': FieldValue.increment(challenge.entryFee), // Додаємо до банку
        });

        // Віднімаємо монети за участь
        transaction.update(_firestore.collection('users').doc(currentUser.uid), {
          'coins': FieldValue.increment(-challenge.entryFee),
        });

        // Записуємо транзакцію в історію
        transaction.set(_firestore.collection('transactions').doc(), {
          'userId': currentUser.uid,
          'type': 'challenge_entry_fee',
          'amount': -challenge.entryFee,
          'challengeId': challengeId,
          'challengeTitle': challenge.title,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
  'Вступна плата за челендж: ${challenge.title}',
  'Challenge entry fee: ${challenge.title}',
),
        });
      });

      return true;
    } catch (e) {
      print('Error joining challenge: $e');
      rethrow;
    }
  }

  // Подати відео на челендж
  Future<bool> submitVideo(String challengeId, String videoUrl) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeRef = _challengesCollection.doc(challengeId);
      
      // Перевірка чи можна подати відео
      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (!challenge.canSubmit) {
        throw Exception('Не можна подати відео на цей челендж');
      }

      // Перевірка чи користувач учасник
      if (!challenge.participants.contains(currentUser.uid)) {
        throw Exception('Ви не учасник цього челенджу');
      }

      // Перевірка чи вже подано відео
      if (challenge.submissions.contains(currentUser.uid)) {
        throw Exception('Ви вже подали відео на цей челендж');
      }

      // Додати відео
      await challengeRef.update({
        'submissions': FieldValue.arrayUnion([currentUser.uid]),
      });

      return true;
    } catch (e) {
      print('Error submitting video: $e');
      rethrow;
    }
  }

  // Проголосувати за відео
  Future<bool> voteForVideo(String challengeId, String userId, Map<String, double> criteria) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Перевірка чи користувач не голосує за себе
      if (currentUser.uid == userId) {
        throw Exception('Не можна голосувати за себе');
      }

      final challengeRef = _challengesCollection.doc(challengeId);
      
      // Перевірка чи можна голосувати
      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (!challenge.canVote) {
        throw Exception('Голосування не відкрите');
      }

      // Перевірка чи користувач вже голосував
      if (challenge.votes.containsKey(currentUser.uid)) {
        throw Exception('Ви вже голосували за це відео');
      }

      // Розрахунок загальної оцінки за критеріями
      final totalRating = (criteria['technical'] ?? 0) * 0.4 +
                          (criteria['creativity'] ?? 0) * 0.3 +
                          (criteria['difficulty'] ?? 0) * 0.2 +
                          (criteria['quality'] ?? 0) * 0.1;

      // Зберегти голос
      await challengeRef.update({
        'votes.${currentUser.uid}': totalRating,
        'detailedVotes.${currentUser.uid}': criteria,
      });

      // Нарахувати монети за голос (+1 монета)
      await _addCoinsToUser(currentUser.uid, 1);
      
      // Записати транзакцію за голосування
      await _firestore.collection('transactions').add({
        'userId': currentUser.uid,
        'type': 'voting_reward',
        'amount': 1,
        'challengeId': challengeId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': I18n.inline(
  'Нагорода за голосування в челенджі',
  'Reward for voting in the challenge',
),
      });

      return true;
    } catch (e) {
      print('Error voting for video: $e');
      rethrow;
    }
  }

  // Завершити челендж та визначити переможців
  Future<bool> completeChallenge(String challengeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeRef = _challengesCollection.doc(challengeId);
      
      // Перевірка чи користувач створювач челенджу
      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (challenge.creatorId != currentUser.uid) {
        throw Exception('Тільки створювач може завершити челендж');
      }

      if (challenge.status != ChallengeStatus.voting) {
        throw Exception('Челендж не в стадії голосування');
      }

      // Розрахунок фінальних оцінок
      final finalScores = <String, double>{};
      for (final submission in challenge.submissions) {
        double totalScore = 0;
        int voteCount = 0;
        
        for (final vote in challenge.votes.values) {
          totalScore += vote;
          voteCount++;
        }
        
        if (voteCount > 0) {
          finalScores[submission] = totalScore / voteCount;
        }
      }

      // Визначення переможців
      final sortedParticipants = finalScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final winners = <String>[];
      if (sortedParticipants.isNotEmpty) {
        winners.add(sortedParticipants[0].key); // 1-е місце
      }
      if (sortedParticipants.length > 1) {
        winners.add(sortedParticipants[1].key); // 2-е місце
      }
      if (sortedParticipants.length > 2) {
        winners.add(sortedParticipants[2].key); // 3-є місце
      }

      // Нарахування призів з записом транзакцій
      if (winners.isNotEmpty) {
        final firstPrize = challenge.firstPlacePrize.toInt();
        await _addCoinsToUser(winners[0], firstPrize);
        await _firestore.collection('transactions').add({
          'userId': winners[0],
          'type': 'challenge_win',
          'amount': firstPrize,
          'challengeId': challengeId,
          'challengeTitle': challenge.title,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
  'Перемога в челенджі: ${challenge.title} (1-е місце)',
  'Challenge win: ${challenge.title} (1st place)',
),
        });
      }
      if (winners.length > 1) {
        final secondPrize = challenge.secondPlacePrize.toInt();
        await _addCoinsToUser(winners[1], secondPrize);
        await _firestore.collection('transactions').add({
          'userId': winners[1],
          'type': 'challenge_second',
          'amount': secondPrize,
          'challengeId': challengeId,
          'challengeTitle': challenge.title,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
  'Друге місце в челенджі: ${challenge.title}',
  'Second place in challenge: ${challenge.title}',
),
        });
      }
      if (winners.length > 2) {
        final thirdPrize = challenge.thirdPlacePrize.toInt();
        await _addCoinsToUser(winners[2], thirdPrize);
        await _firestore.collection('transactions').add({
          'userId': winners[2],
          'type': 'challenge_third',
          'amount': thirdPrize,
          'challengeId': challengeId,
          'challengeTitle': challenge.title,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
  'Третє місце в челенджі: ${challenge.title}',
  'Third place in challenge: ${challenge.title}',
),
        });
      }

      // Оновлення статусу челенджу
      await challengeRef.update({
        'status': ChallengeStatus.completed.toString().split('.').last,
        'finalScores': finalScores,
        'winners': winners,
        'endDate': Timestamp.fromDate(DateTime.now()),
      });

      return true;
    } catch (e) {
      print('Error completing challenge: $e');
      rethrow;
    }
  }

  // Отримати челенджі користувача
  Stream<List<Challenge>> getUserChallenges(String userId) {
    return _challengesCollection
        .where('participants', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList());
  }

  // Отримати створені користувачем челенджі
  Stream<List<Challenge>> getCreatedChallenges(String userId) {
    return _challengesCollection
        .where('creatorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Challenge.fromFirestore(doc))
            .toList());
  }

  // Видалити челендж (тільки створювач)
  Future<bool> deleteChallenge(String challengeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeDoc = await _challengesCollection.doc(challengeId).get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (challenge.creatorId != currentUser.uid) {
        throw Exception('Тільки створювач може видалити челендж');
      }

      await _challengesCollection.doc(challengeId).delete();
      return true;
    } catch (e) {
      print('Error deleting challenge: $e');
      rethrow;
    }
  }

  // Приватний метод для додавання монет користувачу
  Future<void> _addCoinsToUser(String userId, int coins) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      await userRef.update({
        'coins': FieldValue.increment(coins),
      });
    } catch (e) {
      print('Error adding coins to user: $e');
    }
  }

  // Отримати статистику челенджів
  Future<Map<String, dynamic>> getChallengeStats() async {
    try {
      final totalChallenges = await _challengesCollection.count().get();
      final activeChallenges = await _challengesCollection
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      final completedChallenges = await _challengesCollection
          .where('status', isEqualTo: ChallengeStatus.completed.toString().split('.').last)
          .count()
          .get();

      return {
        'total': totalChallenges.count,
        'active': activeChallenges.count,
        'completed': completedChallenges.count,
      };
    } catch (e) {
      print('Error getting challenge stats: $e');
      return {'total': 0, 'active': 0, 'completed': 0};
    }
  }

  // Додати відео до челенджу
  Future<bool> addVideoToChallenge(String challengeId, String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeRef = _challengesCollection.doc(challengeId);
      final challengeDoc = await challengeRef.get();
      
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      
      // Додаємо користувача як учасника, якщо він ще не є учасником
      if (!challenge.participants.contains(userId)) {
        await challengeRef.update({
          'participants': FieldValue.arrayUnion([userId]),
          'currentParticipants': FieldValue.increment(1),
        });
      }

      // Перевірка, чи челендж активний
      final data = challengeDoc.data() as Map<String, dynamic>?;
      final isActive = data?['isActive'] as bool? ?? true;
      if (!isActive) {
        throw Exception('Челендж неактивний. Не можна додавати відео.');
      }

      // Додаємо відео до челенджу
      await challengeRef.update({
        'submissions': FieldValue.arrayUnion([currentUser.uid]),
      });

      return true;
    } catch (e) {
      print('Error adding video to challenge: $e');
      rethrow;
    }
  }

  // Відправити запрошення на челендж
  Future<void> _sendChallengeInvitations(String challengeId, Challenge challenge) async {
    try {
      List<String> targetUserIds = [];

      switch (challenge.audience) {
        case ChallengeAudience.friends:
          // Отримати друзів створювача
          final friendsSnapshot = await _firestore
              .collection('users')
              .doc(challenge.creatorId)
              .collection('friends')
              .get();
          targetUserIds = friendsSnapshot.docs.map((doc) => doc.id).toList();
          break;

        case ChallengeAudience.city:
          // Отримати користувачів з того ж міста
          final cityUsersSnapshot = await _firestore
              .collection('users')
              .where('city', isEqualTo: challenge.city)
              .limit(50) // Обмежуємо кількість
              .get();
          targetUserIds = cityUsersSnapshot.docs
              .map((doc) => doc.id)
              .where((id) => id != challenge.creatorId) // Виключаємо створювача
              .toList();
          break;

        case ChallengeAudience.country:
          // Отримати користувачів з України (або країни створювача)
          final countryUsersSnapshot = await _firestore
              .collection('users')
              .where('country', isEqualTo: 'Україна')
              .limit(100) // Обмежуємо кількість
              .get();
          targetUserIds = countryUsersSnapshot.docs
              .map((doc) => doc.id)
              .where((id) => id != challenge.creatorId) // Виключаємо створювача
              .toList();
          break;

        case ChallengeAudience.world:
          // Отримати випадкових користувачів зі всього світу
          final worldUsersSnapshot = await _firestore
              .collection('users')
              .limit(200) // Обмежуємо кількість
              .get();
          targetUserIds = worldUsersSnapshot.docs
              .map((doc) => doc.id)
              .where((id) => id != challenge.creatorId) // Виключаємо створювача
              .toList();
          break;
      }

      // Відправити нотифікації
      if (targetUserIds.isNotEmpty) {
        await _notificationService.sendBulkChallengeInvitations(
          userIds: targetUserIds,
          challengeId: challengeId,
          challengeTitle: challenge.title,
          creatorName: challenge.creatorName,
          challengeType: challengeTypeToSlug(challenge.type),
        );
        print('Sent ${targetUserIds.length} challenge invitations for ${challenge.title}');
      }
    } catch (e) {
      print('Error sending challenge invitations: $e');
      // Не кидаємо помилку, щоб не зупинити створення челенджу
    }
  }

  // Автоматичне завершення челенджів та відправка нотифікацій
  Future<void> checkAndFinishChallenges() async {
    try {
      final now = DateTime.now();
      
      // Знаходимо челенджі, які закінчилися, але ще не завершені
      final expiredChallengesSnapshot = await _challengesCollection
          .where('isActive', isEqualTo: true)
          .where('status', isNotEqualTo: 'finished')
          .get();
      
      for (final doc in expiredChallengesSnapshot.docs) {
        final challenge = Challenge.fromFirestore(doc);
        
        // Перевіряємо чи челендж закінчився
        if (challenge.endDate.isBefore(now)) {
          await _finishChallenge(challenge);
        }
      }
    } catch (e) {
      print('Error checking and finishing challenges: $e');
    }
  }

  Future<void> _finishChallenge(Challenge challenge) async {
    try {
      // Визначаємо переможців
      final submissionsSnapshot = await _challengesCollection
          .doc(challenge.id)
          .collection('submissions')
          .orderBy('averageRating', descending: true)
          .limit(3)
          .get();
      
      final winners = <Map<String, dynamic>>[];
      final totalPrize = challenge.prizePool;
      
      for (int i = 0; i < submissionsSnapshot.docs.length; i++) {
        final doc = submissionsSnapshot.docs[i];
        final data = doc.data();
        final userId = data['userId'];
        final prize = _calculatePrize(i + 1, totalPrize, submissionsSnapshot.docs.length);
        
        winners.add({
          'userId': userId,
          'position': i + 1,
          'prize': prize,
        });
        
        // Нараховуємо монети
        await _awardPrize(userId, prize, i + 1, challenge.title);
      }
      
      // Оновлюємо статус челенджу
      await _challengesCollection.doc(challenge.id).update({
        'status': 'finished',
        'winners': winners.map((w) => w['userId']).toList(),
        'finishedAt': FieldValue.serverTimestamp(),
      });
      
      // Відправляємо нотифікації всім учасникам
      for (final participantId in challenge.participants) {
        await _notificationService.sendNotification(
          AppNotification(
            id: '',
            userId: participantId,
            type: NotificationType.challengeCompleted,
            title: 'Челендж завершено!',
            message: 'Челендж "${challenge.title}" завершено. Переглянь результати!',
            data: {'challengeId': challenge.id},
            actionUrl: '/challenge/${challenge.id}/results',
            createdAt: DateTime.now(),
          ),
        );
      }
      
      print('Challenge ${challenge.id} finished successfully');
    } catch (e) {
      print('Error finishing challenge: $e');
    }
  }

  double _calculatePrize(int position, double totalPrize, int totalWinners) {
    if (totalWinners < 3) {
      // Якщо менше 3 учасників
      if (position == 1) return totalPrize * 0.7;
      if (position == 2) return totalPrize * 0.3;
    }
    
    // Стандартний розподіл
    switch (position) {
      case 1: return totalPrize * 0.5; // 50%
      case 2: return totalPrize * 0.3; // 30%
      case 3: return totalPrize * 0.2; // 20%
      default: return 0.0;
    }
  }

  Future<void> _awardPrize(String userId, double prize, int position, String challengeTitle) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      await _firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentCoins = (userDoc.data()?['coins'] ?? 0) as num;
        transaction.update(userRef, {
          'coins': currentCoins + prize.toInt(),
        });
      });
      
      // Додаємо запис в історію транзакцій
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('coin_transactions')
          .add({
        'amount': prize.toInt(),
        'type': 'challenge_prize',
        'description': I18n.inline(
  'Приз за ${position}-е місце в челенджі "$challengeTitle"',
  'Prize for ${position} place in challenge "$challengeTitle"',
),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error awarding prize: $e');
    }
  }

  // Видалення завершених челенджів через 2 дні
  Future<void> deleteOldFinishedChallenges() async {
    try {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      
      final oldChallengesSnapshot = await _challengesCollection
          .where('status', isEqualTo: 'finished')
          .where('finishedAt', isLessThan: Timestamp.fromDate(twoDaysAgo))
          .get();
      
      for (final doc in oldChallengesSnapshot.docs) {
        // Видаляємо submissions
        final submissionsSnapshot = await doc.reference.collection('submissions').get();
        for (final subDoc in submissionsSnapshot.docs) {
          await subDoc.reference.delete();
        }
        
        // Видаляємо votes
        final votesSnapshot = await doc.reference.collection('votes').get();
        for (final voteDoc in votesSnapshot.docs) {
          await voteDoc.reference.delete();
        }
        
        // Видаляємо сам челендж
        await doc.reference.delete();
        print('Deleted old challenge: ${doc.id}');
      }
    } catch (e) {
      print('Error deleting old challenges: $e');
    }
  }
}
