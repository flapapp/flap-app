import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flap_app/models/challenge.dart';
import 'package:flap_app/models/notification.dart';
import 'package:flap_app/features/notifications/data/notification_service.dart';
import 'package:flap_app/utils/i18n.dart';
import 'package:flap_app/core/app_auth_context.dart';

class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Перевірка ліміту челенджів для користувача
      final userDoc = await _firestore.collection('users').doc(currentUser.id).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final maxChallenges = userData?['maxChallengesPerMonth'] ?? 1;
      final isSubscriptionActive = userData?['subscriptionActive'] ?? false;
      
      if (!isSubscriptionActive) {
        final userChallenges = await _challengesCollection
            .where('creatorId', isEqualTo: currentUser.id)
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
        final userRef = _firestore.collection('users').doc(currentUser.id);
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
        'userId': currentUser.id,
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
      final currentUser = AppAuthContext.currentUser;
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
      if (challenge.participants.contains(currentUser.id)) {
        throw Exception('Ви вже учасник цього челенджу');
      }

      // Перевірити чи достатньо монет
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.id)
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
          'participants': FieldValue.arrayUnion([currentUser.id]),
          'currentParticipants': FieldValue.increment(1),
          'prizePool': FieldValue.increment(challenge.entryFee), // Додаємо до банку
        });

        // Віднімаємо монети за участь
        transaction.update(_firestore.collection('users').doc(currentUser.id), {
          'coins': FieldValue.increment(-challenge.entryFee),
        });

        // Записуємо транзакцію в історію
        transaction.set(_firestore.collection('transactions').doc(), {
          'userId': currentUser.id,
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
      final currentUser = AppAuthContext.currentUser;
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
      if (!challenge.participants.contains(currentUser.id)) {
        throw Exception('Ви не учасник цього челенджу');
      }

      // Перевірка чи вже подано відео
      if (challenge.submissions.contains(currentUser.id)) {
        throw Exception('Ви вже подали відео на цей челендж');
      }

      // Додати відео
      await challengeRef.update({
        'submissions': FieldValue.arrayUnion([currentUser.id]),
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
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Перевірка чи користувач не голосує за себе
      if (currentUser.id == userId) {
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
      if (challenge.votes.containsKey(currentUser.id)) {
        throw Exception('Ви вже голосували за це відео');
      }

      // Розрахунок загальної оцінки за критеріями
      final totalRating = (criteria['technical'] ?? 0) * 0.4 +
                          (criteria['creativity'] ?? 0) * 0.3 +
                          (criteria['difficulty'] ?? 0) * 0.2 +
                          (criteria['quality'] ?? 0) * 0.1;

      // Зберегти голос
      await challengeRef.update({
        'votes.${currentUser.id}': totalRating,
        'detailedVotes.${currentUser.id}': criteria,
      });

      // Нарахувати монети за голос (+1 монета)
      await _addCoinsToUser(currentUser.id, 1);
      
      // Записати транзакцію за голосування
      await _firestore.collection('transactions').add({
        'userId': currentUser.id,
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
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeRef = _challengesCollection.doc(challengeId);
      final challengeDoc = await challengeRef.get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (challenge.creatorId != currentUser.id) {
        throw Exception('Тільки створювач може завершити челендж');
      }

      if (challenge.status == ChallengeStatus.completed) {
        throw Exception('Челендж вже завершено');
      }

      if (challenge.status != ChallengeStatus.voting) {
        throw Exception('Челендж не в стадії голосування');
      }

      final result = await _finalizeChallenge(challenge);
      await _notifyParticipantsAboutCompletion(challenge, result);

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
      final currentUser = AppAuthContext.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final challengeDoc = await _challengesCollection.doc(challengeId).get();
      if (!challengeDoc.exists) {
        throw Exception('Челендж не знайдено');
      }

      final challenge = Challenge.fromFirestore(challengeDoc);
      if (challenge.creatorId != currentUser.id) {
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
      final currentUser = AppAuthContext.currentUser;
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
        'submissions': FieldValue.arrayUnion([currentUser.id]),
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

      final expiredChallengesSnapshot = await _challengesCollection
          .where('isActive', isEqualTo: true)
          .where('endDate', isLessThan: Timestamp.fromDate(now))
          .limit(25)
          .get();

      for (final doc in expiredChallengesSnapshot.docs) {
        final challenge = Challenge.fromFirestore(doc);
        if (challenge.status == ChallengeStatus.completed) {
          continue;
        }
        await _finishChallenge(challenge);
      }
    } catch (e) {
      print('Error checking and finishing challenges: $e');
    }
  }

  Future<void> _finishChallenge(Challenge challenge) async {
    try {
      final result = await _finalizeChallenge(challenge);
      await _notifyParticipantsAboutCompletion(challenge, result);
      print('Challenge ${challenge.id} finished successfully');
    } catch (e) {
      print('Error finishing challenge: $e');
    }
  }

  // Видалення завершених челенджів через 2 дні
  Future<void> deleteOldFinishedChallenges() async {
    try {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      
      final oldChallengesSnapshot = await _challengesCollection
          .where('status', isEqualTo: 'completed')
          .where('completedAt', isLessThan: Timestamp.fromDate(twoDaysAgo))
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

  Future<_ChallengeWinnersPayload> _finalizeChallenge(
    Challenge challenge,
  ) async {
    final challengeRef = _challengesCollection.doc(challenge.id);
    final submissionsSnapshot = await challengeRef
        .collection('submissions')
        .orderBy('averageRating', descending: true)
        .get();

    final winners = <String>[];
    final finalScores = <String, double>{};
    final winnerPrizes = <String, int>{};
    final prizePool = _effectivePrizePool(challenge);
    final prizes = _prizeBreakdown(prizePool);

    for (int i = 0; i < submissionsSnapshot.docs.length && i < 3; i++) {
      final data = submissionsSnapshot.docs[i].data();
      final winnerId = (data['userId'] ?? '').toString();
      if (winnerId.isEmpty) {
        continue;
      }

      final rating =
          ((data['averageRating'] ?? data['rating'] ?? 0.0) as num).toDouble();
      final prize = prizes[i];

      winners.add(winnerId);
      finalScores[winnerId] = rating;
      winnerPrizes[winnerId] = prize;

      if (prize > 0) {
        await _addCoinsToUser(winnerId, prize);
        await _firestore.collection('transactions').add({
          'userId': winnerId,
          'type': 'challenge_prize',
          'amount': prize,
          'challengeId': challenge.id,
          'challengeTitle': challenge.title,
          'position': i + 1,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
            'Приз за ${i + 1}-е місце в челенджі "${challenge.title}"',
            'Prize for place ${i + 1} in "${challenge.title}"',
          ),
        });
        await _notificationService.sendChallengeResultNotification(
          toUserId: winnerId,
          challengeTitle: challenge.title,
          challengeId: challenge.id,
          position: i + 1,
          coinsWon: prize,
        );
      }
    }

    await challengeRef.update({
      'status': ChallengeStatus.completed.toString().split('.').last,
      'winners': winners,
      'finalScores': finalScores,
      'winnerPrizes': winnerPrizes,
      'isActive': false,
      'completedAt': FieldValue.serverTimestamp(),
    });

    return _ChallengeWinnersPayload(
      winners: winners,
      finalScores: finalScores,
      winnerPrizes: winnerPrizes,
    );
  }

  Future<void> _notifyParticipantsAboutCompletion(
    Challenge challenge,
    _ChallengeWinnersPayload result,
  ) async {
    final winnersSet = result.winnersSet;
    for (final participantId in challenge.participants.toSet()) {
      if (participantId.isEmpty || winnersSet.contains(participantId)) {
        continue;
      }
      await _notificationService.sendChallengeCompletedNotification(
        toUserId: participantId,
        challengeTitle: challenge.title,
        challengeId: challenge.id,
      );
    }
  }

  double _effectivePrizePool(Challenge challenge) {
    if (challenge.prizePool > 0) {
      return challenge.prizePool;
    }
    final participantCount = challenge.participants.isNotEmpty
        ? challenge.participants.length
        : challenge.currentParticipants;
    return (participantCount * challenge.entryFee).toDouble();
  }

  List<int> _prizeBreakdown(double prizePool) {
    final total = prizePool.round();
    if (total <= 0) {
      return [0, 0, 0];
    }
    final first = (total * 0.5).round();
    final second = (total * 0.3).round();
    final remaining = total - first - second;
    final third = remaining < 0 ? 0 : remaining;
    return [first, second, third];
  }
}

class _ChallengeWinnersPayload {
  const _ChallengeWinnersPayload({
    required this.winners,
    required this.finalScores,
    required this.winnerPrizes,
  });

  final List<String> winners;
  final Map<String, double> finalScores;
  final Map<String, int> winnerPrizes;

  Set<String> get winnersSet => winners.toSet();
}
