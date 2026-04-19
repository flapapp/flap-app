import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/match.dart';
import '../../../teams/data/models/app_team.dart';
import '../../../notifications/data/services/notification_service.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Отримати всі доступні матчі (тільки відкриті)
  Stream<List<Match>> getAvailableMatches() {
  return _firestore
      .collection('matches')
      .where('status', isEqualTo: 'open')
      .orderBy('date', descending: false)
      .snapshots()
      .map((snapshot) {
        final matches = snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            .toList();

        // Прострочені незапущені матчі не мають лишатися "доступними".
        for (final m in matches.where((m) => m.isUnplayedByTimeout)) {
          _markAsUnplayedTimedOut(m.id); // fire-and-forget
        }

        return matches.where((m) => !m.isUnplayedByTimeout).toList();
      });
}

Future<void> _markAsUnplayedTimedOut(String matchId) async {
  try {
    await _firestore.collection('matches').doc(matchId).update({
      'status': 'cancelled',
      'unplayed': true,
      'unplayedReason': 'timeout_24h_no_start',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {
    // best-effort
  }
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

      if (match.isUnplayedByTimeout) {
        await _markAsUnplayedTimedOut(matchId);
        return false;
      }

      if (match.isTeamMatch) {
        return false;
      }
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

        if (match.isUnplayedByTimeout) {
          await _markAsUnplayedTimedOut(matchId);
          throw Exception('Match expired and marked as unplayed');
        }

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
      if (initialMatch.participants.length < 2) {
        throw Exception('Недостатньо гравців для формування команд (мінімум 2)');
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
        if (match.participants.length < 2) {
          throw Exception('Недостатньо гравців для формування команд (мінімум 2)');
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
        final names = MatchUtils.generateTeamNames(2);
        final nameA = names[0];
        final nameB = names[1];

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
        final generated = MatchUtils.generateTeamNames(2);
        final funA = generated[0];
        final funB = generated[1];
        final nameA = existingNameA.isNotEmpty ? existingNameA : funA;
        final nameB = existingNameB.isNotEmpty ? existingNameB : (funB == nameA ? MatchUtils.generateTeamNames(3)[2] : funB);

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
    Future<bool> updateTeamsFlexible(String matchId, List<List<String>> teams) async {
  try {
    final docRef = _firestore.collection('matches').doc(matchId);

    final allPlayerIds = teams.expand((t) => t).toList();
    final ratings = await _getPlayerRatings(allPlayerIds);

    final generatedNames = MatchUtils.generateTeamNames(teams.length);
    final List<Map<String, dynamic>> firestoreTeams = [];
    for (var i = 0; i < teams.length; i++) {
      final ids = teams[i];
      firestoreTeams.add({
        'name': generatedNames[i],
        'playerIds': ids,
        'averageRating': _calculateTeamAverageRating(ids, ratings),
      });
    }

    final batch = _firestore.batch();
    batch.update(docRef, {
      'teams': firestoreTeams,
      'teamCount': teams.length,
      'teamA': firestoreTeams.isNotEmpty ? firestoreTeams[0] : null,
      'teamB': firestoreTeams.length > 1 ? firestoreTeams[1] : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final fxCol = docRef.collection('fixtures');
    final oldFx = await fxCol.get();
    for (final d in oldFx.docs) {
      batch.delete(d.reference);
    }

    if (teams.length > 2) {
      for (var i = 0; i < teams.length; i++) {
        for (var j = i + 1; j < teams.length; j++) {
          final newFxRef = fxCol.doc();
          batch.set(newFxRef, {
            'teamAIndex': i,
            'teamBIndex': j,
            'teamAName': firestoreTeams[i]['name'],
            'teamBName': firestoreTeams[j]['name'],
            'scoreA': null,
            'scoreB': null,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      batch.update(docRef, {'currentGameIndex': 0});
    }

    await batch.commit();
    await docRef.update({'multiTeamStats': []});
    return true;
  } catch (e) {
    print('Error updateTeamsFlexible: $e');
    return false;
  }
}  

  Future<List<Map<String, dynamic>>> getFixtures(String matchId) async {
  final q = await _firestore.collection('matches').doc(matchId).collection('fixtures')
      .orderBy(FieldPath.documentId).get();
  return q.docs.map((d) => {'id': d.id, ...((d.data()) as Map<String, dynamic>)}).toList();
}

Future<bool> finishGame(String matchId, String fixtureId, int scoreA, int scoreB) async {
  try {
    final docRef = _firestore.collection('matches').doc(matchId);
    final fxRef = docRef.collection('fixtures').doc(fixtureId);
    await fxRef.update({
      'scoreA': scoreA,
      'scoreB': scoreB,
      'status': 'finished',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final all = await docRef.collection('fixtures').get();
    final allFinished = all.docs.every((d) => (d.data()['status'] ?? '') == 'finished');
    if (allFinished) {
      await docRef.update({
        'status': 'finished',
        'finishedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return true;
  } catch (e) {
    print('Error finishGame: $e');
    return false;
  }
}

Future<void> promptFinishGame(BuildContext context, String matchId, int fixtureIndex, String aName, String bName) async {
  final fixtures = await getFixtures(matchId);
  if (fixtureIndex < 0 || fixtureIndex >= fixtures.length) return;
  final f = fixtures[fixtureIndex];
  final ctrlA = TextEditingController();
  final ctrlB = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (ctx) {
    return AlertDialog(
      title: Text('Результат: $aName vs $bName'),
      content: Row(children: [
        Expanded(child: TextField(controller: ctrlA, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Голи $aName'))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: ctrlB, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Голи $bName'))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Зберегти')),
      ],
    );
  });
  if (ok == true) {
    final a = int.tryParse(ctrlA.text) ?? 0;
    final b = int.tryParse(ctrlB.text) ?? 0;
    await finishGame(matchId, f['id'] as String, a, b);
  }
}

/// Створює фікстури для матчу з 3+ командами, якщо їх ще немає
Future<void> ensureFixtures(String matchId) async {
  final docRef = _firestore.collection('matches').doc(matchId);
  final snap = await docRef.get();
  if (!snap.exists) return;
  final data = snap.data() as Map<String, dynamic>;
  final teams = (data['teams'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
  if (teams.length <= 2) return;

  final already = await docRef.collection('fixtures').limit(1).get();
  if (already.docs.isNotEmpty) return;

  final List<Map<String, dynamic>> fixtures = [];
  for (var i = 0; i < teams.length; i++) {
    for (var j = i + 1; j < teams.length; j++) {
      fixtures.add({
        'teamAIndex': i,
        'teamBIndex': j,
        'teamAName': (teams[i]['name'] ?? 'Team A').toString(),
        'teamBName': (teams[j]['name'] ?? 'Team B').toString(),
        'scoreA': null,
        'scoreB': null,
        'status': 'pending',
      });
    }
  }
  final fxCol = docRef.collection('fixtures');
  for (final f in fixtures) {
    await fxCol.add(f);
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

        if (match.isUnplayedByTimeout) {
          await _markAsUnplayedTimedOut(matchId);
          throw Exception('Match expired and marked as unplayed');
        }

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
          final generated = MatchUtils.generateTeamNames(2);
          final funA = generated[0];
          final funB = generated[1];
          final nameA = existingNameA.isNotEmpty ? existingNameA : funA;
          final nameB = existingNameB.isNotEmpty ? existingNameB : funB;

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

        if (match.isTeamMatch) {
          final rosterA = match.teamRosters['teamA'] ??
              match.teamA?.playerIds ??
              const <String>[];
          final rosterB = match.teamRosters['teamB'] ??
              match.teamB?.playerIds ??
              const <String>[];
          if (rosterA.isEmpty || rosterB.isEmpty) {
            throw Exception('Склади команд не заповнені');
          }
          final statusesA = match.teamRosterStatus['teamA'] ?? const {};
          final statusesB = match.teamRosterStatus['teamB'] ?? const {};
          final confirmedA = statusesA.values
              .where((status) => status == 'confirmed')
              .length;
          final confirmedB = statusesB.values
              .where((status) => status == 'confirmed')
              .length;
          if (confirmedA + confirmedB < 2) {
            throw Exception('Потрібно мінімум два підтверджені гравці');
          }
        } else if (match.participants.length < 2) {
          throw Exception('Потрібно щонайменше 2 учасники');
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
  Future<bool> finishMatch(
    String matchId,
    MatchResult result,
    int teamAScore,
    int teamBScore, {
    Map<String, int> goalsByPlayer = const {},
  }) async {
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

      if (match.hasTeams && goalsByPlayer.isNotEmpty) {
        final assignments = match.playerTeamAssignments;
        int totalA = 0;
        int totalB = 0;
        goalsByPlayer.forEach((playerId, goals) {
          final teamKey = assignments[playerId];
          if (teamKey == 'teamA') {
            totalA += goals;
          } else if (teamKey == 'teamB') {
            totalB += goals;
          }
        });
        if (totalA > teamAScore || totalB > teamBScore) {
          throw Exception(
              'Сума голів заявлених гравців перевищує рахунок команди');
        }
      }

      tx.update(docRef, {
        'status': 'finished',
        'result': result.toString().split('.').last,
        'teamAScore': teamAScore,
        'teamBScore': teamBScore,
        'goalsByPlayer': goalsByPlayer,
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
      final playerGoals = goalsByPlayer[uid] ?? 0;
      final updates = <String, dynamic>{
        'totalMatches': FieldValue.increment(1),
        'matches': FieldValue.increment(1),
        'matchesPlayed': FieldValue.increment(1),
        'lastMatchAt': FieldValue.serverTimestamp(),
      };
      if (playerGoals > 0) {
        updates['goals'] = FieldValue.increment(playerGoals);
      }
      batch.update(_firestore.collection('users').doc(uid), updates);
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
    await _updateTeamsAfterMatch(m, teamAScore, teamBScore, goalsByPlayer);
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

  Future<bool> deleteMatch(String matchId) async {
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
        if (match.isInProgress || match.isFinished) {
          throw Exception('Неможливо видалити матч після старту');
        }
        tx.delete(docRef);
        return true;
      });
      if (!ok) return false;

      // Clean nested collections (best-effort outside transaction)
      await _deleteSubcollection(matchId, 'playerRatings');
      await _deleteSubcollection(matchId, 'fixtures');

      // Remove pending team match requests referencing this match
      final reqSnap = await _firestore
          .collection('teamMatchRequests')
          .where('matchId', isEqualTo: matchId)
          .get();
      for (final doc in reqSnap.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('Error deleting match: $e');
      return false;
    }
  }

  Future<void> _deleteSubcollection(String matchId, String subcollection) async {
    final parent = _firestore.collection('matches').doc(matchId);
    final snap = await parent.collection(subcollection).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

    Future<bool> saveMultiTeamResults(
    String matchId,
    List<Map<String, int>> stats,
  ) async {
    try {
      final docRef = _firestore.collection('matches').doc(matchId);
      await docRef.update({
        'multiTeamStats': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error saveMultiTeamResults: $e');
      return false;
    }
  }

  Future<void> _updateTeamsAfterMatch(
    Match match,
    int teamAScore,
    int teamBScore,
    Map<String, int> goalsByPlayer,
  ) async {
    if (match.teamAId == null || match.teamBId == null) return;
    final aRef = _firestore.collection('teams').doc(match.teamAId);
    final bRef = _firestore.collection('teams').doc(match.teamBId);
    final aDoc = await aRef.get();
    final bDoc = await bRef.get();
    if (!aDoc.exists || !bDoc.exists) return;
    final teamA = AppTeam.fromDoc(aDoc);
    final teamB = AppTeam.fromDoc(bDoc);
    final rosterA =
        match.teamRosters['teamA'] ?? match.teamA?.playerIds ?? const [];
    final rosterB =
        match.teamRosters['teamB'] ?? match.teamB?.playerIds ?? const [];
    final resultA = teamAScore.compareTo(teamBScore);
    final now = Timestamp.now();
    final summaryA = {
      'matchId': match.id,
      'opponentTeamId': match.teamBId,
      'opponentName': teamB.name,
      'score': '$teamAScore:$teamBScore',
      'result': resultA > 0
          ? 'win'
          : resultA < 0
              ? 'loss'
              : 'draw',
      'playedAt': now,
    };
    final summaryB = {
      'matchId': match.id,
      'opponentTeamId': match.teamAId,
      'opponentName': teamA.name,
      'score': '$teamBScore:$teamAScore',
      'result': resultA < 0
          ? 'win'
          : resultA > 0
              ? 'loss'
              : 'draw',
      'playedAt': now,
    };
    final recentA = [summaryA, ...teamA.recentMatches];
    final recentB = [summaryB, ...teamB.recentMatches];
    final aPlayerUpdates = <String, dynamic>{};
    final bPlayerUpdates = <String, dynamic>{};
    final aGoalDeltas = <String, int>{};
    final bGoalDeltas = <String, int>{};
    for (final uid in rosterA) {
      final goals = goalsByPlayer[uid] ?? 0;
      if (goals > 0) {
        aPlayerUpdates['playerGoals.$uid'] = FieldValue.increment(goals);
        aGoalDeltas[uid] = goals;
      }
    }
    for (final uid in rosterB) {
      final goals = goalsByPlayer[uid] ?? 0;
      if (goals > 0) {
        bPlayerUpdates['playerGoals.$uid'] = FieldValue.increment(goals);
        bGoalDeltas[uid] = goals;
      }
    }
    final batch = _firestore.batch();
    batch.update(aRef, {
      'wins': FieldValue.increment(resultA > 0 ? 1 : 0),
      'losses': FieldValue.increment(resultA < 0 ? 1 : 0),
      'draws': FieldValue.increment(resultA == 0 ? 1 : 0),
      'goalsFor': FieldValue.increment(teamAScore),
      'goalsAgainst': FieldValue.increment(teamBScore),
      'recentMatches': recentA.take(5).toList(),
      'updatedAt': now,
      ...aPlayerUpdates,
    });
    batch.update(bRef, {
      'wins': FieldValue.increment(resultA < 0 ? 1 : 0),
      'losses': FieldValue.increment(resultA > 0 ? 1 : 0),
      'draws': FieldValue.increment(resultA == 0 ? 1 : 0),
      'goalsFor': FieldValue.increment(teamBScore),
      'goalsAgainst': FieldValue.increment(teamAScore),
      'recentMatches': recentB.take(5).toList(),
      'updatedAt': now,
      ...bPlayerUpdates,
    });
    try {
      await batch.commit();
    } catch (e) {
      print('Warning updating teams standings: $e');
    }

    await _updateTeamStatsDoc(
      teamId: match.teamAId!,
      teamName: teamA.name,
      goalsFor: teamAScore,
      goalsAgainst: teamBScore,
      isWin: resultA > 0,
      isDraw: resultA == 0,
      playerGoalDeltas: aGoalDeltas,
      summary: summaryA,
    );
    await _updateTeamStatsDoc(
      teamId: match.teamBId!,
      teamName: teamB.name,
      goalsFor: teamBScore,
      goalsAgainst: teamAScore,
      isWin: resultA < 0,
      isDraw: resultA == 0,
      playerGoalDeltas: bGoalDeltas,
      summary: summaryB,
    );
  }

  Future<void> _updateTeamStatsDoc({
    required String teamId,
    required String teamName,
    required int goalsFor,
    required int goalsAgainst,
    required bool isWin,
    required bool isDraw,
    required Map<String, int> playerGoalDeltas,
    required Map<String, dynamic> summary,
  }) async {
    final ref = _firestore.collection('teamStats').doc(teamId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const <String, dynamic>{};
      final currentWins = (data['wins'] ?? 0) as int;
      final currentDraws = (data['draws'] ?? 0) as int;
      final currentLosses = (data['losses'] ?? 0) as int;
      final currentGoalsFor = (data['goalsFor'] ?? 0) as int;
      final currentGoalsAgainst = (data['goalsAgainst'] ?? 0) as int;
      final playerGoals = Map<String, int>.from(
        (data['playerGoals'] ?? const <String, dynamic>{}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      );
      playerGoalDeltas.forEach((playerId, delta) {
        playerGoals[playerId] = (playerGoals[playerId] ?? 0) + delta;
      });

      final recent = List<Map<String, dynamic>>.from(
        (data['recentMatches'] as List?) ?? const [],
      );
      recent.insert(0, summary);
      final trimmedRecent = recent.take(5).toList();

      tx.set(
        ref,
        {
          'teamId': teamId,
          'teamName': teamName,
          'wins': currentWins + (isWin ? 1 : 0),
          'draws': currentDraws + (isDraw ? 1 : 0),
          'losses': currentLosses + ((!isWin && !isDraw) ? 1 : 0),
          'goalsFor': currentGoalsFor + goalsFor,
          'goalsAgainst': currentGoalsAgainst + goalsAgainst,
          'playerGoals': playerGoals,
          'recentMatches': trimmedRecent,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> setTeamRoster({
    required String matchId,
    required String teamKey,
    required AppTeam team,
    required List<String> playerIds,
  }) async {
    final matchRef = _firestore.collection('matches').doc(matchId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(matchRef);
      if (!snap.exists) {
        throw Exception('Матч не знайдено');
      }
      final data = snap.data() as Map<String, dynamic>;
      final rosterStatusRaw =
          Map<String, dynamic>.from(data['teamRosterStatus'] ?? {});
      rosterStatusRaw[teamKey] = {
        for (final id in playerIds) id: 'pending',
      };

      final teamField = teamKey == 'teamA' ? 'teamA' : 'teamB';
      final statusField = teamKey == 'teamA' ? 'teamAStatus' : 'teamBStatus';
      final teamIdField = teamKey == 'teamA' ? 'teamAId' : 'teamBId';

      final existingTeam =
          (data[teamField] as Map<String, dynamic>?);

      final updates = <String, dynamic>{
        'teamRosters.$teamKey': playerIds,
        'teamRosterStatus': rosterStatusRaw,
        statusField: 'pending',
        teamIdField: team.id,
        teamField: {
          'name': team.name,
          'playerIds': playerIds,
          'averageRating':
              ((existingTeam?['averageRating'] ?? 0.0) as num).toDouble(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      tx.update(matchRef, updates);
    });
  }

  Future<void> respondToRosterInvite({
    required String matchId,
    required String teamKey,
    required bool accept,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      throw Exception('Потрібна авторизація');
    }
    final matchRef = _firestore.collection('matches').doc(matchId);

    bool notifyOrganizer = false;
    String organizerId = '';
    String readyTeamAName = 'Team A';
    String readyTeamBName = 'Team B';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(matchRef);
      if (!snap.exists) {
        throw Exception('Матч не знайдено');
      }

      final data = snap.data() as Map<String, dynamic>;
      organizerId = (data['organizerId'] ?? '').toString();
      final rosterStatusRaw =
          Map<String, dynamic>.from(data['teamRosterStatus'] ?? {});
      if (!rosterStatusRaw.containsKey(teamKey)) {
        throw Exception('Склад не знайдено');
      }
      final teamStatusMap =
          Map<String, dynamic>.from(rosterStatusRaw[teamKey] ?? {});
      if (!teamStatusMap.containsKey(currentUserId)) {
        throw Exception('Вас не заявлено на цей матч');
      }

      teamStatusMap[currentUserId] = accept ? 'confirmed' : 'declined';
      rosterStatusRaw[teamKey] = teamStatusMap;

      final participants =
          List<String>.from(data['participants'] ?? const <String>[]);
      if (accept) {
        if (!participants.contains(currentUserId)) {
          participants.add(currentUserId);
        }
      } else {
        participants.remove(currentUserId);
      }

      final updates = <String, dynamic>{
        'teamRosterStatus': rosterStatusRaw,
        'participants': participants,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final allConfirmed = teamStatusMap.values
          .every((status) => status == 'confirmed');
      bool currentTeamConfirmed = false;
      if (allConfirmed) {
        updates[teamKey == 'teamA' ? 'teamAStatus' : 'teamBStatus'] =
            'confirmed';
        currentTeamConfirmed = true;
      }

      final currentTeamAStatus = (data['teamAStatus'] ?? 'pending').toString();
      final currentTeamBStatus = (data['teamBStatus'] ?? 'pending').toString();
      final newTeamAStatus = teamKey == 'teamA'
          ? (currentTeamConfirmed ? 'confirmed' : currentTeamAStatus)
          : currentTeamAStatus;
      final newTeamBStatus = teamKey == 'teamB'
          ? (currentTeamConfirmed ? 'confirmed' : currentTeamBStatus)
          : currentTeamBStatus;

      final alreadyNotified = data['teamsReadyNotified'] ?? false;
      final isTeamMatch = data['teamMatch'] == true;
      if (isTeamMatch &&
          !alreadyNotified &&
          newTeamAStatus == 'confirmed' &&
          newTeamBStatus == 'confirmed') {
        updates['teamsReadyNotified'] = true;
        updates['teamsReadyNotifiedAt'] = FieldValue.serverTimestamp();
        readyTeamAName =
            (data['teamA']?['name'] ?? 'Team A').toString();
        readyTeamBName =
            (data['teamB']?['name'] ?? 'Team B').toString();
        notifyOrganizer = organizerId.isNotEmpty;
      }

      tx.update(matchRef, updates);
    });

    if (notifyOrganizer && organizerId.isNotEmpty) {
      await NotificationService().sendTeamMatchReadyNotification(
        toUserId: organizerId,
        matchId: matchId,
        teamAName: readyTeamAName,
        teamBName: readyTeamBName,
      );
    }
  }

  Future<void> updateCoverPhoto({
    required String matchId,
    required String photoUrl,
  }) async {
    try {
      await _firestore.collection('matches').doc(matchId).update({
        'coverPhotoUrl': photoUrl,
        'coverPhotoUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating match cover photo: $e');
      rethrow;
    }
  }
}