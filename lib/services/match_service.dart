import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Отримати всі доступні матчі (тільки відкриті)
  Stream<List<Match>> getAvailableMatches() {
    return _firestore
        .collection('matches')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            .where((match) => match.status == MatchStatus.open)
            .toList());
  }

  // Отримати матчі користувача (де він учасник)
  Stream<List<Match>> getUserMatches(String userId) {
    return _firestore
        .collection('matches')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            .where((match) => match.participants.contains(userId))
            .toList());
  }

  // Створити новий матч
  Future<void> createMatch(Match match) async {
    await _firestore.collection('matches').add(match.toFirestore());
  }

  // Приєднатися до матчу
    // СТАРИЙ МЕТОД - ЗАКОМЕНТОВАНО
  // Future<bool> joinMatch(String matchId, String userId) async {
  //   try {
  //     final docRef = _firestore.collection('matches').doc(matchId);

  //     // Отримати поточний матч
  //     final doc = await docRef.get();
  //     if (!doc.exists) return false;

  //     final match = Match.fromFirestore(doc);

  //     // Перевірити чи користувач вже учасник
  //     if (match.participants.contains(userId)) {
  //       return false; // вже учасник
  //     }

  //     // Перевірити чи є вільні місця
  //     if (match.currentPlayers >= match.maxPlayers) {
  //       return false; // матч заповнений
  //     }

  //     // Додати користувача та оновити лічильник
  //     await docRef.update({
  //       'participants': FieldValue.arrayUnion([userId]),
  //       'currentPlayers': FieldValue.increment(1),
  //     });

  //     // Якщо після додавання матч заповнився — позначити 'full'
  //     if (match.currentPlayers + 1 >= match.maxPlayers) {
  //       await docRef.update({'status': 'full'});
  //     }

  //     return true;
  //   } catch (e) {
  //     print('Error joining match: $e');
  //     return false;
  //   }
  // }

  // НОВИЙ МЕТОД - ПОДАЧА ЗАЯВКИ
  Future<bool> joinMatch(String matchId, String userId) async {
    // Тепер joinMatch викликає applyForMatch
    return await applyForMatch(matchId, userId);
  }

  // Вийти з матчу
  Future<bool> leaveMatch(String matchId, String userId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');

        final match = Match.fromFirestore(snap);

        // Якщо користувач не у списку учасників — нічого не робимо
        if (!match.participants.contains(userId)) return;

        final updatedParticipants = List<String>.from(match.participants)
          ..remove(userId);
        final int newCurrentPlayers =
    (match.currentPlayers - 1).clamp(0, match.maxPlayers).toInt();

        final Map<String, dynamic> updates = <String, dynamic>{
          'participants': updatedParticipants,
          'currentPlayers': newCurrentPlayers,
        };

        // Якщо був 'full' і стало менше максимальної — повертаємо 'open'
        if (match.status == MatchStatus.full &&
            newCurrentPlayers < match.maxPlayers) {
          updates['status'] = 'open';
        }

        tx.update(docRef, updates);
      });

      return true;
    } catch (e) {
      print('Error leaving match: $e');
      return false;
    }
  }

  // Розпочати матч (для організатора)
  Future<void> startMatch(String matchId) async {
    await _firestore.collection('matches').doc(matchId).update({
      'status': 'inProgress',
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Завершити матч (для організатора)
  Future<void> finishMatch(String matchId) async {
    await _firestore.collection('matches').doc(matchId).update({
      'status': 'finished',
      'finishedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
    // Подати заявку на участь у матчі
  Future<bool> applyForMatch(String matchId, String userId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      // Отримати поточний матч
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final match = Match.fromFirestore(doc);

      // Перевірити чи користувач вже учасник
      if (match.participants.contains(userId)) {
        return false; // вже учасник
      }

      // Перевірити чи вже є заявка
      if (match.pendingApplications.contains(userId)) {
        return false; // заявка вже подана
      }

      // Перевірити чи не була заявка відхилена
      if (match.rejectedApplications.contains(userId)) {
        return false; // заявка була відхилена
      }

      // Додати заявку
      await docRef.update({
        'pendingApplications': FieldValue.arrayUnion([userId]),
      });

      return true;
    } catch (e) {
      print('Error applying for match: $e');
      return false;
    }
  }

  // Прийняти заявку користувача
  Future<bool> acceptApplication(String matchId, String userId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');

        final match = Match.fromFirestore(snap);

        // Перевірити чи є заявка
        if (!match.pendingApplications.contains(userId)) {
          throw Exception('No pending application from this user');
        }

        // Перевірити чи є вільні місця
        if (match.currentPlayers >= match.maxPlayers) {
          throw Exception('Match is full');
        }

        // Перемістити з заявок до учасників
        final updatedPending = List<String>.from(match.pendingApplications)
          ..remove(userId);
        final updatedParticipants = List<String>.from(match.participants)
          ..add(userId);

        final updates = <String, dynamic>{
          'pendingApplications': updatedPending,
          'participants': updatedParticipants,
          'currentPlayers': FieldValue.increment(1),
        };

        // Якщо матч заповнився - змінити статус
        if (match.currentPlayers + 1 >= match.maxPlayers) {
          updates['status'] = 'full';
        }

        tx.update(docRef, updates);
      });

      return true;
    } catch (e) {
      print('Error accepting application: $e');
      return false;
    }
  }

  // Відхилити заявку користувача
  Future<bool> rejectApplication(String matchId, String userId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');

        final match = Match.fromFirestore(snap);

        // Перевірити чи є заявка
        if (!match.pendingApplications.contains(userId)) {
          throw Exception('No pending application from this user');
        }

        // Перемістити з заявок до відхилених
        final updatedPending = List<String>.from(match.pendingApplications)
          ..remove(userId);
        final updatedRejected = List<String>.from(match.rejectedApplications)
          ..add(userId);

        tx.update(docRef, {
          'pendingApplications': updatedPending,
          'rejectedApplications': updatedRejected,
        });
      });

      return true;
    } catch (e) {
      print('Error rejecting application: $e');
      return false;
    }
  }

  // Отримати заявки на матч
  Stream<List<String>> getMatchApplications(String matchId) {
    return _firestore
        .collection('matches')
        .doc(matchId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      return List<String>.from(data['pendingApplications'] ?? []);
    });
  }
}