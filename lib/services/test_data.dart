import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';

class TestDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createTestMatches() async {
    try {
      // Тестовий матч 1
      final match1 = Match(
        id: 'test_match_1',
        title: 'Футбольний матч у парку',
        description: 'Дружня гра для всіх рівнів. Приєднуйтесь до веселої гри!',
        organizerId: 'test_user_1',
        organizerName: 'Тестовий користувач',
        date: DateTime.now().add(Duration(days: 1)),
        time: '18:00',
        location: 'Центральний парк',
        city: 'Київ',
        currentPlayers: 8,
        maxPlayers: 14,
        // Participants left empty to avoid missing user docs in rating init
        participants: [],
        level: MatchLevel.intermediate,
        cost: 50.0,
        autoBalance: true,
        isPrivate: false,
        status: MatchStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Тестовий матч 2
      final match2 = Match(
        id: 'test_match_2',
        title: 'Професійна гра на стадіоні',
        description: 'Серйозна гра для досвідчених гравців. Високий рівень гри!',
        organizerId: 'test_user_2',
        organizerName: 'Професіонал',
        date: DateTime.now().add(Duration(days: 2)),
        time: '20:00',
        location: 'Олімпійський стадіон',
        city: 'Київ',
        currentPlayers: 12,
        maxPlayers: 22,
        participants: [],
        level: MatchLevel.professional,
        cost: 100.0,
        autoBalance: true,
        isPrivate: false,
        status: MatchStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Тестовий матч 3
      final match3 = Match(
        id: 'test_match_3',
        title: 'Початковий рівень для новачків',
        description: 'Ідеально для тих, хто тільки починає грати в футбол',
        organizerId: 'test_user_3',
        organizerName: 'Тренер-новачок',
        date: DateTime.now().add(Duration(days: 3)),
        time: '16:00',
        location: 'Шкільне поле',
        city: 'Львів',
        currentPlayers: 5,
        maxPlayers: 10,
        participants: [],
        level: MatchLevel.beginner,
        cost: 0.0,
        autoBalance: true,
        isPrivate: false,
        status: MatchStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Збереження в Firestore
      await _firestore.collection('matches').doc('test_match_1').set(match1.toFirestore());
      await _firestore.collection('matches').doc('test_match_2').set(match2.toFirestore());
      await _firestore.collection('matches').doc('test_match_3').set(match3.toFirestore());

      print('✅ Тестові матчі створені успішно!');
    } catch (e) {
      print('❌ Помилка створення тестових матчів: $e');
    }
  }

  static Future<void> clearTestData() async {
    try {
      await _firestore.collection('matches').doc('test_match_1').delete();
      await _firestore.collection('matches').doc('test_match_2').delete();
      await _firestore.collection('matches').doc('test_match_3').delete();
      print('✅ Тестові дані видалені!');
    } catch (e) {
      print('❌ Помилка видалення тестових даних: $e');
    }
  }
}