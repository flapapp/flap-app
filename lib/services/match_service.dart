import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/match.dart';
import 'notification_service.dart';

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
    // Створити новий матч
  Future<String> createMatch(Match match) async {
  final docRef = await _firestore.collection('matches').add(match.toFirestore());
  final matchId = docRef.id;

  // Надсилаємо інвайти, якщо матч приватний і є запрошені
  try {
    if (match.isPrivate && match.invitedFriends.isNotEmpty) {
      final orgDoc = await _firestore.collection('users').doc(match.organizerId).get();
      final organizerName = (orgDoc.data()?['displayName'] ?? orgDoc.data()?['name'] ?? 'Організатор').toString();
      for (final uid in match.invitedFriends) {
        await NotificationService().sendMatchInvite(
          toUserId: uid,
          matchId: matchId,
          organizerName: organizerName,
        );
      }
    }
  } catch (_) {}

  return matchId;
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

// Якщо команди вже були — приберемо гравця з команд і перерахуємо середній рейтинг
if (match.hasTeams) {
  final List<String> teamAPlayers = List<String>.from(match.teamA?.playerIds ?? const <String>[])..remove(userId);
  final List<String> teamBPlayers = List<String>.from(match.teamB?.playerIds ?? const <String>[])..remove(userId);

  final Map<String, double> ratings = await _getPlayerRatings([...teamAPlayers, ...teamBPlayers]);

  updates['teamA'] = {
    'name': match.teamA?.name ?? 'Команда A',
    'playerIds': teamAPlayers,
    'averageRating': _calculateTeamAverageRating(teamAPlayers, ratings),
    'playerRatings': match.teamA?.playerRatings ?? <String, double>{},
  };
  updates['teamB'] = {
    'name': match.teamB?.name ?? 'Команда B',
    'playerIds': teamBPlayers,
    'averageRating': _calculateTeamAverageRating(teamBPlayers, ratings),
    'playerRatings': match.teamB?.playerRatings ?? <String, double>{},
  };
}

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

      try {
  final snapAfter = await docRef.get();
  if (snapAfter.exists) {
    final m = Match.fromFirestore(snapAfter);
    final applicantDoc = await _firestore.collection('users').doc(userId).get();
    final applicantName = (applicantDoc.data()?['displayName'] ?? applicantDoc.data()?['name'] ?? 'Гравець').toString();
    await NotificationService().sendMatchApplicationSubmitted(
      toOrganizerId: m.organizerId,
      matchId: matchId,
      applicantName: applicantName,
    );
  }
} catch (_) {}

      return true;
    } catch (e) {
      print('Error applying for match: $e');
      return false;
    }
  }

    // Прийняти заявку користувача
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
        final updatedPending = List<String>.from(match.pendingApplications)..remove(userId);
        final updatedParticipants = List<String>.from(match.participants)..add(userId);

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

      // Надіслати сповіщення про підтвердження ЗАРАЗ, одразу після транзакції
      try {
        final updatedSnap = await _firestore.collection('matches').doc(matchId).get();
        if (updatedSnap.exists) {
          final m = Match.fromFirestore(updatedSnap);
          final orgDoc = await _firestore.collection('users').doc(m.organizerId).get();
          final organizerName = (orgDoc.data()?['displayName'] ?? orgDoc.data()?['name'] ?? 'Організатор').toString();
          await NotificationService().sendMatchApplicationAccepted(
            toUserId: userId,
            matchId: matchId,
            organizerName: organizerName,
          );
        }
      } catch (_) {}

      // Якщо команди вже існують – додати гравця до однієї з команд
      try {
        final snapshot = await docRef.get();
        if (snapshot.exists) {
          final updated = Match.fromFirestore(snapshot);
          if (updated.hasTeams) {
            final List<String> teamAPlayers = List<String>.from(updated.teamA?.playerIds ?? const <String>[]);
            final List<String> teamBPlayers = List<String>.from(updated.teamB?.playerIds ?? const <String>[]);

            // Уникаємо дублювань
            if (teamAPlayers.contains(userId) || teamBPlayers.contains(userId)) {
              return true;
            }

            // Отримаємо рейтинги для коректного перерахунку
            final Map<String, double> ratings = await _getPlayerRatings([
              ...teamAPlayers,
              ...teamBPlayers,
              userId,
            ]);

            // Вибір цільової команди
            final double avgA = _calculateTeamAverageRating(teamAPlayers, ratings);
            final double avgB = _calculateTeamAverageRating(teamBPlayers, ratings);

            bool addToA;
            if (teamAPlayers.length < teamBPlayers.length) {
              addToA = true;
            } else if (teamBPlayers.length < teamAPlayers.length) {
              addToA = false;
            } else {
              // рівна кількість: додамо в команду з нижчим середнім рейтингом
              addToA = avgA <= avgB;
            }

            if (addToA) {
              teamAPlayers.add(userId);
            } else {
              teamBPlayers.add(userId);
            }

            final double newAvgA = _calculateTeamAverageRating(teamAPlayers, ratings);
            final double newAvgB = _calculateTeamAverageRating(teamBPlayers, ratings);

            await docRef.update({
              'teamA': {
                'name': updated.teamA?.name ?? 'Команда A',
                'playerIds': teamAPlayers,
                'averageRating': newAvgA,
                'playerRatings': updated.teamA?.playerRatings ?? <String, double>{},
              },
              'teamB': {
                'name': updated.teamB?.name ?? 'Команда B',
                'playerIds': teamBPlayers,
                'averageRating': newAvgB,
                'playerRatings': updated.teamB?.playerRatings ?? <String, double>{},
              },
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (_) {}

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
      try {
  final updated = await _firestore.collection('matches').doc(matchId).get();
  if (updated.exists) {
    final m = Match.fromFirestore(updated);
    final orgDoc = await _firestore.collection('users').doc(m.organizerId).get();
    final organizerName = (orgDoc.data()?['displayName'] ?? orgDoc.data()?['name'] ?? 'Організатор').toString();
    await NotificationService().sendMatchApplicationRejected(
      toUserId: userId,
      matchId: matchId,
      organizerName: organizerName,
    );
  }
} catch (_) {}

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
        final names = MatchUtils.teamNames;
        final base = DateTime.now().millisecondsSinceEpoch;
        final idxA = base % names.length;
        final idxB = (idxA + 1) % names.length; // ensure distinct
        final nameA = names[idxA];
        final nameB = names[idxB];

        final teamA = Team(
          name: nameA,
          playerIds: teamAPlayers,
          averageRating: _calculateTeamAverageRating(teamAPlayers, playerRatings),
        );
        final teamB = Team(
          name: nameB,
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

                // Preserve existing team names or pick fun defaults if missing
        final existingNameA = match.teamA?.name ?? '';
        final existingNameB = match.teamB?.name ?? '';
        final fun = MatchUtils.teamNames;
        final seed = DateTime.now().millisecondsSinceEpoch;
        final funA = fun[seed % fun.length];
        final funB = fun[(seed + 1) % fun.length];
        final nameA = existingNameA.isNotEmpty ? existingNameA : funA;
        final nameB = existingNameB.isNotEmpty ? existingNameB : (funB == nameA ? fun[(seed + 2) % fun.length] : funB);

        final teamA = Team(
          name: nameA,
          playerIds: teamAPlayers,
          averageRating: _calculateTeamAverageRating(teamAPlayers, ratings),
        );
        final teamB = Team(
          name: nameB,
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
        // Дозволяємо старт, якщо щонайменше 2 учасники. Якщо команди відсутні — формуємо 2 команди автоматично
        if (!match.hasTeams) {
          final participants = List<String>.from(match.participants);
          if (participants.length < 2) {
            throw Exception('Потрібно щонайменше 2 учасники');
          }

          // Просте розбиття на 2 команди (щоб не блокувати старт)
          final half = (participants.length / 2).ceil();
          final teamAPlayers = participants.take(half).toList();
          final teamBPlayers = participants.skip(half).toList();

          final existingNameA = match.teamA?.name ?? '';
          final existingNameB = match.teamB?.name ?? '';
          final fun = ['Леви', 'Сови', 'Тигри', 'Орли', 'Вовки'];
          final seed = DateTime.now().millisecondsSinceEpoch % fun.length;
          final funA = fun[seed];
          final funB = fun[(seed + 1) % fun.length];
          final nameA = existingNameA.isNotEmpty ? existingNameA : funA;
          final nameB = existingNameB.isNotEmpty ? existingNameB : (funB == nameA ? fun[(seed + 2) % fun.length] : funB);

          // Оновлюємо документ матчa з сформованими командами
          tx.update(docRef, {
            'teamA': {
              'name': nameA,
              'playerIds': teamAPlayers,
              'averageRating': 0.0,
            },
            'teamB': {
              'name': nameB,
              'playerIds': teamBPlayers,
              'averageRating': 0.0,
            },
          });
        }

        if (match.isInProgress) {
          throw Exception('Матч вже почався');
        }
        
        // Дозволяємо початок матчу навіть якщо не набралася повна кількість гравців
        
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

    final ok = await _firestore.runTransaction((tx) async {
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
    if (!ok) return false;

    // Після успішного завершення — інкрементуємо лічильники гравцям
    final snapAfter = await docRef.get();
    if (!snapAfter.exists) return true;
    final m = Match.fromFirestore(snapAfter);

    final WriteBatch batch = _firestore.batch();
    for (final uid in m.participants) {
  batch.update(_firestore.collection('users').doc(uid), {
    'totalMatches': FieldValue.increment(1),
    'matches': FieldValue.increment(1),
    'matchesPlayed': FieldValue.increment(1),
    'lastMatchAt': FieldValue.serverTimestamp(),
  });
}

    // (опційно) перемоги/поразки/нічиї, якщо є склади
    if (m.hasTeams) {
      final a = m.teamA?.playerIds ?? const <String>[];
      final b = m.teamB?.playerIds ?? const <String>[];
      if (teamAScore > teamBScore) {
       for (final uid in a) {
  batch.update(_firestore.collection('users').doc(uid), {
    'wonMatches': FieldValue.increment(1),
    'wins': FieldValue.increment(1),
  });
}
for (final uid in b) {
  batch.update(_firestore.collection('users').doc(uid), {
    'lostMatches': FieldValue.increment(1),
    'losses': FieldValue.increment(1),
  });
}
      } else if (teamBScore > teamAScore) {
        for (final uid in b) {
  batch.update(_firestore.collection('users').doc(uid), {
    'wonMatches': FieldValue.increment(1),
    'wins': FieldValue.increment(1),
  });
}
for (final uid in a) {
  batch.update(_firestore.collection('users').doc(uid), {
    'lostMatches': FieldValue.increment(1),
    'losses': FieldValue.increment(1),
  });
}
      } else {
        for (final uid in {...a, ...b}) {
  batch.update(_firestore.collection('users').doc(uid), {
    'drawMatches': FieldValue.increment(1),
    'draws': FieldValue.increment(1),
  });
}
      }
    }

    await batch.commit();
    try {
  final teamAName = m.teamA?.name ?? 'Команда A';
  final teamBName = m.teamB?.name ?? 'Команда B';
  for (final uid in m.participants) {
    await NotificationService().sendMatchFinished(
      toUserId: uid,
      matchId: snapAfter.id,
      teamAName: teamAName,
      teamBName: teamBName,
      teamAScore: teamAScore,
      teamBScore: teamBScore,
    );
  }
} catch (_) {}
    return true;
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