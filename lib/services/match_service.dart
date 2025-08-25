import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Отримати всі доступні матчі
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

  // Отримати матчі користувача
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
  Future<bool> joinMatch(String matchId, String userId) async {
  try {
    final docRef = _firestore.collection('matches').doc(matchId);
    
    // Отримати поточний матч
    final doc = await docRef.get();
    if (!doc.exists) return false;
    
    final match = Match.fromFirestore(doc);
    
    // Перевірити чи користувач вже учасник
    if (match.participants.contains(userId)) {
      return false; // Вже учасник
    }
    
    // Перевірити чи є місця
    if (match.participants.length >= match.maxPlayers) {
      return false; // Матч заповнений
    }
    
    // Додати користувача та оновити лічильник
    await docRef.update({
      'participants': FieldValue.arrayUnion([userId]),
      'currentPlayers': FieldValue.increment(1),
    });
    
    // Якщо матч заповнений, змінити статус
    if (match.participants.length + 1 >= match.maxPlayers) {
      await docRef.update({'status': 'full'});
    }
    
    return true;
  } catch (e) {
    print('Error joining match: $e');
    return false;
  }
}
}