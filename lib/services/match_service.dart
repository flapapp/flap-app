import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Отримати всі доступні матчі
  Stream<List<Match>> getAvailableMatches() {
    return _firestore
        .collection('matches')
        .where('status', isEqualTo: MatchStatus.open.toString())
        .orderBy('dateTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Match.fromFirestore(doc))
            .toList());
  }

  // Отримати матчі користувача
  Stream<List<Match>> getUserMatches(String userId) {
    return _firestore
        .collection('matches')
        .where('players', arrayContains: userId)
        .orderBy('dateTime', descending: true)
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
  Future<void> joinMatch(String matchId, String userId) async {
    await _firestore.collection('matches').doc(matchId).update({
      'players': FieldValue.arrayUnion([userId]),
    });
  }
}