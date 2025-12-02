import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/i18n.dart';

class ChallengeCompletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Завершити челендж та розподілити призи
  Future<void> completeChallengeAndDistributePrizes(String challengeId) async {
    try {
      final challengeDoc = await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) return;

      final challengeData = challengeDoc.data() as Map<String, dynamic>;
      final prizePool = (challengeData['prizePool'] ?? 0.0).toDouble();
      
      // Отримуємо всі submission з оцінками
      final submissionsSnapshot = await _firestore
          .collection('challenges')
          .doc(challengeId)
          .collection('submissions')
          .orderBy('averageRating', descending: true)
          .get();

      final submissions = submissionsSnapshot.docs;
      
      if (submissions.length < 2) {
        // Якщо менше 2 учасників - повертаємо гроші
        await _refundChallenge(challengeId, challengeData);
        return;
      }

      // Розподіл призів: 1-е: 50%, 2-е: 30%, 3-є: 20%
      final prizes = [
        (prizePool * 0.5).round(), // 1-е місце
        (prizePool * 0.3).round(), // 2-е місце  
        (prizePool * 0.2).round(), // 3-є місце
      ];

      final winners = <String>[];
      final finalScores = <String, double>{};

      // Нараховуємо призи переможцям
      for (int i = 0; i < submissions.length && i < 3; i++) {
        final submissionData = submissions[i].data() as Map<String, dynamic>;
        final winnerId = submissionData['userId'];
        final rating = (submissionData['averageRating'] ?? 0.0).toDouble();
        
        winners.add(winnerId);
        finalScores[winnerId] = rating;
        
        if (i < prizes.length && prizes[i] > 0) {
          // Нараховуємо монети переможцю
          await _firestore.collection('users').doc(winnerId).update({
            'coins': FieldValue.increment(prizes[i]),
          });

          // Записуємо транзакцію
          await _firestore.collection('transactions').add({
            'userId': winnerId,
            'type': 'challenge_prize',
            'amount': prizes[i],
            'challengeId': challengeId,
            'place': i + 1,
            'timestamp': FieldValue.serverTimestamp(),
            'description': I18n.inline(
  'Приз за ${i + 1}-е місце в челенджі: ${prizes[i]} монет',
  'Prize for ${i + 1} place in the challenge: ${prizes[i]} coins',
),
          });
        }
      }

      // Оновлюємо челендж
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'completed',
        'winners': winners,
        'finalScores': finalScores,
        'completedAt': FieldValue.serverTimestamp(),
      });

      print('Challenge $challengeId completed successfully');
    } catch (e) {
      print('Error completing challenge: $e');
    }
  }

  // Повернути гроші учасникам якщо недостатньо учасників
  Future<void> _refundChallenge(String challengeId, Map<String, dynamic> challengeData) async {
    try {
      final participants = List<String>.from(challengeData['participants'] ?? []);
      final entryFee = challengeData['entryFee'] ?? 0;

      // Повертаємо гроші всім учасникам
      for (final participantId in participants) {
        await _firestore.collection('users').doc(participantId).update({
          'coins': FieldValue.increment(entryFee),
        });

        // Записуємо транзакцію
        await _firestore.collection('transactions').add({
          'userId': participantId,
          'type': 'challenge_refund',
          'amount': entryFee,
          'challengeId': challengeId,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
  'Повернення коштів за челендж (скасовано)',
  'Challenge refund (canceled)',
),
        });
      }

      // Позначаємо челендж як скасований
      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': 'Недостатньо учасників',
      });
    } catch (e) {
      print('Error refunding challenge: $e');
    }
  }

  // Автоматичне завершення челенджів за розкладом
  Future<void> checkAndCompleteExpiredChallenges() async {
    try {
      final now = DateTime.now();
      
      // Знаходимо челенджі що мають завершитися
      final expiredChallenges = await _firestore
          .collection('challenges')
          .where('status', whereIn: ['voting', 'submission'])
          .where('endDate', isLessThan: Timestamp.fromDate(now))
          .limit(10)
          .get();

      for (final doc in expiredChallenges.docs) {
        await completeChallengeAndDistributePrizes(doc.id);
      }
    } catch (e) {
      print('Error checking expired challenges: $e');
    }
  }
}

