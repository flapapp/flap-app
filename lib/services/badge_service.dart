import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/badge.dart';
import '../utils/i18n.dart';

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _badgesCollection =>
      _firestore.collection('badges');
  CollectionReference get _usersCollection =>
      _firestore.collection('users');

  Stream<List<Badge>> getAvailableBadges() {
    return _badgesCollection
        .where('isAvailable', isEqualTo: true)
        .orderBy('price')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Badge.fromFirestore(doc))
            .toList());
  }

  Stream<List<Badge>> getBadgesByCategory(String category) {
    return _badgesCollection
        .where('category', isEqualTo: category)
        .where('isAvailable', isEqualTo: true)
        .orderBy('price')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Badge.fromFirestore(doc))
            .toList());
  }

  Future<List<String>> getUserBadges(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return List<String>.from(userData['badges'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting user badges: $e');
      return [];
    }
  }

  Future<bool> userOwnsBadge(String userId, String badgeId) async {
    final userBadges = await getUserBadges(userId);
    return userBadges.contains(badgeId);
  }

  Future<bool> purchaseBadge(String badgeId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final badgeDoc = await _badgesCollection.doc(badgeId).get();
      if (!badgeDoc.exists) {
        throw Exception('Бейдж не знайдено');
      }

      final badge = Badge.fromFirestore(badgeDoc);
      if (!badge.isAvailable) {
        throw Exception('Цей бейдж недоступний для покупки');
      }

      final alreadyOwned = await userOwnsBadge(currentUser.uid, badgeId);
      if (alreadyOwned) {
        throw Exception('Ви вже маєте цей бейдж');
      }

      final userDoc = await _usersCollection.doc(currentUser.uid).get();
      if (!userDoc.exists) {
        throw Exception('Дані користувача не знайдено');
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userCoins = userData['coins'] ?? 0;

      if (userCoins < badge.price) {
        throw Exception('Недостатньо монет. Потрібно: ${badge.price}, у вас: $userCoins');
      }

      await _firestore.runTransaction((transaction) async {
        transaction.update(_usersCollection.doc(currentUser.uid), {
          'coins': FieldValue.increment(-badge.price),
          'badges': FieldValue.arrayUnion([badgeId]),
        });

        final localizedBadgeName = badge.localizedName;
        transaction.set(_firestore.collection('transactions').doc(), {
          'userId': currentUser.uid,
          'type': 'badge_purchase',
          'amount': -badge.price,
          'badgeId': badgeId,
          'badgeName': localizedBadgeName,
          'timestamp': FieldValue.serverTimestamp(),
          'description': I18n.inline(
            'Покупка бейджу: $localizedBadgeName',
            'Badge purchase: $localizedBadgeName',
          ),
        });
      });

      return true;
    } catch (e) {
      print('Error purchasing badge: $e');
      rethrow;
    }
  }

  Future<void> initializeDefaultBadges() async {
    try {
      final defaultBadges = Badge.getDefaultBadges();

      for (final badge in defaultBadges) {
        final existingBadge = await _badgesCollection.doc(badge.id).get();
        if (!existingBadge.exists) {
          await _badgesCollection.doc(badge.id).set(badge.toFirestore());
          print('Added badge: ${badge.localizedName}');
        }
      }
    } catch (e) {
      print('Error initializing default badges: $e');
    }
  }

  Future<bool> awardBadge(String userId, String badgeId, String reason) async {
    try {
      final alreadyOwned = await userOwnsBadge(userId, badgeId);
      if (alreadyOwned) {
        return false;
      }

      await _usersCollection.doc(userId).update({
        'badges': FieldValue.arrayUnion([badgeId]),
      });

      await _firestore.collection('transactions').add({
        'userId': userId,
        'type': 'badge_awarded',
        'amount': 0,
        'badgeId': badgeId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': I18n.inline(
          'Отримано бейдж: $reason',
          'Badge received: $reason',
        ),
      });

      return true;
    } catch (e) {
      print('Error awarding badge: $e');
      return false;
    }
  }

  Future<Badge?> getBadge(String badgeId) async {
    try {
      final doc = await _badgesCollection.doc(badgeId).get();
      if (doc.exists) {
        return Badge.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting badge: $e');
      return null;
    }
  }

  Future<List<Badge>> getUserBadgeObjects(String userId) async {
    try {
      final badgeIds = await getUserBadges(userId);
      final badges = <Badge>[];

      for (final badgeId in badgeIds) {
        final badge = await getBadge(badgeId);
        if (badge != null) {
          badges.add(badge);
        }
      }

      return badges;
    } catch (e) {
      print('Error getting user badge objects: $e');
      return [];
    }
  }

  List<String> getBadgeCategories() {
    return ['starter', 'skill', 'achievement', 'legendary', 'special'];
  }

  String getCategoryDisplayName(String category) {
    switch (category) {
      case 'starter':
        return 'Початкові';
      case 'skill':
        return 'Навички';
      case 'achievement':
        return 'Досягнення';
      case 'legendary':
        return 'Легендарні';
      case 'special':
        return 'Спеціальні';
      default:
        return 'Інші';
    }
  }

  Future<void> checkAndAwardActivityBadges(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final stats = userData['stats'] as Map<String, dynamic>? ?? {};

      if (!await userOwnsBadge(userId, 'rookie')) {
        await awardBadge(userId, 'rookie', 'Перший крок у FLAP');
      }

      final friendsCount = (userData['friendsCount'] ?? 0) as int;
      if (friendsCount >= 5 && !await userOwnsBadge(userId, 'social')) {
        await awardBadge(userId, 'social', '5+ друзів');
      }

      final matchesPlayed = (stats['matchesPlayed'] ?? 0) as int;
      if (matchesPlayed >= 50 && !await userOwnsBadge(userId, 'veteran')) {
        await awardBadge(userId, 'veteran', '50+ матчів');
      }

      final avgVideoRating = (userData['avgVideoRating'] ?? 0.0) as double;
      if (avgVideoRating >= 4.0 && !await userOwnsBadge(userId, 'skillful')) {
        await awardBadge(userId, 'skillful', 'Середня оцінка відео 4.0+');
      }

    } catch (e) {
      print('Error checking activity badges: $e');
    }
  }
}