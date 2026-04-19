import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/badge.dart';
import '../../../../utils/i18n.dart';

class BadgeService {
  static Future<void>? _initializationFuture;
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
            .map((doc) {
              final badge = Badge.fromFirestore(doc);
              return badge.copyWith(price: _resolveEffectiveBadgePrice(badge));
            })
            .toList());
  }

  Stream<List<Badge>> getBadgesByCategory(String category) {
    return _badgesCollection
        .where('category', isEqualTo: category)
        .where('isAvailable', isEqualTo: true)
        .orderBy('price')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final badge = Badge.fromFirestore(doc);
              return badge.copyWith(price: _resolveEffectiveBadgePrice(badge));
            })
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

      final firestoreBadge = Badge.fromFirestore(badgeDoc);
      final badge = firestoreBadge.copyWith(
        price: _resolveEffectiveBadgePrice(firestoreBadge),
      );
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

      final effectivePrice = _resolveEffectiveBadgePrice(badge);

      if (userCoins < effectivePrice) {
        throw Exception('Недостатньо монет. Потрібно: $effectivePrice, у вас: $userCoins');
      }

      await _firestore.runTransaction((transaction) async {
        transaction.update(_usersCollection.doc(currentUser.uid), {
          'coins': FieldValue.increment(-effectivePrice),
          'badges': FieldValue.arrayUnion([badgeId]),
        });

        final localizedBadgeName = badge.localizedName;
        transaction.set(_firestore.collection('transactions').doc(), {
          'userId': currentUser.uid,
          'type': 'badge_purchase',
          'amount': -effectivePrice,
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
    _initializationFuture ??= _syncDefaultBadges();
    await _initializationFuture;
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
        final badge = Badge.fromFirestore(doc);
        return badge.copyWith(price: _resolveEffectiveBadgePrice(badge));
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

  int _resolveEffectiveBadgePrice(Badge badge) {
    for (final defaultBadge in Badge.getDefaultBadges()) {
      if (defaultBadge.id == badge.id) {
        return defaultBadge.price;
      }
    }
    return badge.price;
  }

  Future<void> _syncDefaultBadges() async {
    try {
      final defaultBadges = Badge.getDefaultBadges();
      for (final badge in defaultBadges) {
        await _badgesCollection.doc(badge.id).set(
          badge.toFirestore(),
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print('Error initializing default badges: $e');
      _initializationFuture = null;
      rethrow;
    }
  }
}