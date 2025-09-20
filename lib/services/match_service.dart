import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Отримати всі доступні матчі (тільки відкриті)
  Stream<List<Match>> getAvailableMatches() {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: 'open')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            .toList());
  }

    // Отримати матчі користувача (де він учасник)
  Stream<List<Match>> getUserMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('participants', arrayContains: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
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

    // Подати заявку на участь у матчі
  Future<bool> applyForMatch(String matchId, String userId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      // Отримати поточний матч
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final match = Match.fromFirestore(doc);
      // Приватний матч: заявки лише від запрошених
if (match.isPrivate && !match.invitedFriends.contains(userId)) {
  return false;
}

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

final currentUserId = FirebaseAuth.instance.currentUser?.uid;
if (currentUserId == null || currentUserId != match.organizerId) {
  throw Exception('Only organizer can perform this action');
}

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

final currentUserId = FirebaseAuth.instance.currentUser?.uid;
if (currentUserId == null || currentUserId != match.organizerId) {
  throw Exception('Only organizer can perform this action');
}

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
      // Автоматичне формування команд
  Future<bool> autoBalanceTeams(String matchId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      // Попереднє читання поза транзакцією (менше часу блокування)
      final initialSnap = await docRef.get();
      if (!initialSnap.exists) throw Exception('Match not found');

      final initialMatch = Match.fromFirestore(initialSnap);

      // Перевірки до транзакції
      if (initialMatch.participants.length < 4) {
        throw Exception('Недостатньо гравців для формування команд (мінімум 4)');
      }
      if (initialMatch.hasTeams) {
        throw Exception('Команди вже сформовані');
      }

      // Отримуємо рейтинги гравців ПОЗА транзакцією (паралельно, див. _getPlayerRatings)
      final playerRatings = await _getPlayerRatings(initialMatch.participants);

      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');

        final match = Match.fromFirestore(snap);

final currentUserId = FirebaseAuth.instance.currentUser?.uid;
if (currentUserId == null || currentUserId != match.organizerId) {
  throw Exception('Only organizer can perform this action');
}

        // Повторні перевірки всередині транзакції
        if (match.participants.length < 4) {
          throw Exception('Недостатньо гравців для формування команд (мінімум 4)');
        }
        if (match.hasTeams) {
          throw Exception('Команди вже сформовані');
        }

        // Сортуємо гравців за рейтингом (від найвищого до найнижчого)
        final sortedPlayers = match.participants.toList()
          ..sort((a, b) => (playerRatings[b] ?? 0.0).compareTo(playerRatings[a] ?? 0.0));

        // Розподіляємо гравців "змійкою"
        final teamAPlayers = <String>[];
        final teamBPlayers = <String>[];
        for (int i = 0; i < sortedPlayers.length; i++) {
          (i % 2 == 0 ? teamAPlayers : teamBPlayers).add(sortedPlayers[i]);
        }

        // Створюємо команди
        final teamA = Team(
          name: 'Команда A',
          playerIds: teamAPlayers,
          averageRating: _calculateTeamAverageRating(teamAPlayers, playerRatings),
        );
        final teamB = Team(
          name: 'Команда B',
          playerIds: teamBPlayers,
          averageRating: _calculateTeamAverageRating(teamBPlayers, playerRatings),
        );

        // Оновлюємо матч
        tx.update(docRef, {
          'teamA': teamA.toFirestore(),
          'teamB': teamB.toFirestore(),
          'status': 'full',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error auto-balancing teams: $e');
      return false;
    }
  }
  
    // Отримання рейтингів гравців
  Future<Map<String, double>> _getPlayerRatings(List<String> playerIds) async {
    final List<Future<MapEntry<String, double>>> futures =
        playerIds.map((String playerId) async {
      try {
        final userDoc = await _firestore.collection('users').doc(playerId).get();
        if (userDoc.exists) {
          final Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          final double rating = (userData['rating'] is num)
              ? (userData['rating'] as num).toDouble()
              : 0.0;
          return MapEntry<String, double>(playerId, rating);
        }
      } catch (_) {}
      return MapEntry<String, double>(playerId, 0.0);
    }).toList();

    final List<MapEntry<String, double>> entries = await Future.wait(futures);
    return Map<String, double>.fromEntries(entries);
  }
  
  // Розрахунок середнього рейтингу команди
  double _calculateTeamAverageRating(List<String> playerIds, Map<String, double> ratings) {
    if (playerIds.isEmpty) return 0.0;
    
    double totalRating = 0.0;
    int ratedPlayers = 0;
    
    for (String playerId in playerIds) {
      if (ratings.containsKey(playerId)) {
        totalRating += ratings[playerId]!;
        ratedPlayers++;
      }
    }
        return ratedPlayers > 0 ? totalRating / ratedPlayers : 0.0;
  }

  // Оновити склади команд вручну
  Future<bool> updateTeams(String matchId, List<String> teamAPlayers, List<String> teamBPlayers) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      // Отримаємо рейтинги поза транзакцією
      final Map<String, double> ratings = await _getPlayerRatings([...teamAPlayers, ...teamBPlayers]);

      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');

        final match = Match.fromFirestore(snap);

        // Перевірки
        final all = {...teamAPlayers, ...teamBPlayers}.toList();
        if (all.length != teamAPlayers.length + teamBPlayers.length) {
          throw Exception('Гравець не може бути у двох командах');
        }
        if (all.toSet().difference(match.participants.toSet()).isNotEmpty) {
          throw Exception('У складах є гравці, яких немає серед учасників матчу');
        }

        final teamA = Team(
          name: 'Команда A',
          playerIds: teamAPlayers,
          averageRating: _calculateTeamAverageRating(teamAPlayers, ratings),
        );
        final teamB = Team(
          name: 'Команда B',
          playerIds: teamBPlayers,
          averageRating: _calculateTeamAverageRating(teamBPlayers, ratings),
        );

        tx.update(docRef, {
          'teamA': teamA.toFirestore(),
          'teamB': teamB.toFirestore(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error updateTeams: $e');
      return false;
    }
  }

    // Почати матч
  Future<bool> startMatch(String matchId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);
      
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');
        
        final match = Match.fromFirestore(snap);

final currentUserId = FirebaseAuth.instance.currentUser?.uid;
if (currentUserId == null || currentUserId != match.organizerId) {
  throw Exception('Only organizer can perform this action');
}
        
        // Перевіряємо чи можна почати матч
        if (!match.hasTeams) {
          throw Exception('Спочатку потрібно сформувати команди');
        }
        
        if (match.isInProgress) {
          throw Exception('Матч вже почався');
        }
        
        // Оновлюємо статус матчу
        tx.update(docRef, {
          'status': 'inProgress',
          'startedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return true;
      });
    } catch (e) {
      print('Error starting match: $e');
      return false;
    }
  }
  
  // Завершити матч
  Future<bool> finishMatch(String matchId, MatchResult result, int teamAScore, int teamBScore) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);
      
      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');
        
        final match = Match.fromFirestore(snap);

final currentUserId = FirebaseAuth.instance.currentUser?.uid;
if (currentUserId == null || currentUserId != match.organizerId) {
  throw Exception('Only organizer can perform this action');
}
        
        if (!match.isInProgress) {
          throw Exception('Матч не почався або вже завершений');
        }
        
        // Оновлюємо матч
        tx.update(docRef, {
          'status': 'finished',
          'result': result.toString().split('.').last,
          'teamAScore': teamAScore,
          'teamBScore': teamBScore,
          'finishedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        return true;
      });
    } catch (e) {
      print('Error finishing match: $e');
      return false;
    }
  }
  
    // Отримати матчі для оцінювання
  Stream<List<Match>> getMatchesForRating(String userId) {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: 'finished')
        .where('participants', arrayContains: userId)
        .orderBy('finishedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            // Клієнтська перевірка: ще не оцінював цей користувач
            .where((match) => !match.playerRatings.any((r) => r.ratedBy == userId))
            .toList());
  }
    // Скасувати матч
  Future<bool> cancelMatch(String matchId) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);

      return await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) throw Exception('Match not found');

        final match = Match.fromFirestore(snap);

        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null || currentUserId != match.organizerId) {
          throw Exception('Only organizer can perform this action');
        }

        if (match.isFinished || match.isCancelled) {
          throw Exception('Матч вже завершено або скасовано');
        }

        tx.update(docRef, {
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      print('Error cancelling match: $e');
      return false;
    }
  }
}