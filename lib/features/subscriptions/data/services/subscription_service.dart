import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/coin_ledger.dart';
import '../../data/models/subscription.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _subscriptionsCollection =>
      _firestore.collection('subscriptions');

  // Get user's current subscription
  Future<Subscription?> getUserSubscription(String userId) async {
    try {
      final subscriptionDoc = await _subscriptionsCollection
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (subscriptionDoc.docs.isEmpty) {
        // Create default free subscription
        return await _createFreeSubscription(userId);
      }

      return Subscription.fromFirestore(subscriptionDoc.docs.first);
    } catch (e) {
      print('Error getting user subscription: $e');
      return await _createFreeSubscription(userId);
    }
  }

  // Get user subscription stream
  Stream<Subscription?> getUserSubscriptionStream(String userId) {
    return _subscriptionsCollection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }
          return Subscription.fromFirestore(snapshot.docs.first);
        });
  }

  // Check if user has active subscription
  Future<bool> hasActiveSubscription([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;

    final subscription = await getUserSubscription(userId);
    return subscription != null && 
           subscription.isActive && 
           subscription.type != SubscriptionType.free;
  }

  // Get subscription type
  Future<SubscriptionType> getSubscriptionType([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return SubscriptionType.free;

    final subscription = await getUserSubscription(userId);
    return subscription?.type ?? SubscriptionType.free;
  }

  // Create free subscription for new users
  Future<Subscription> _createFreeSubscription(String userId) async {
    final now = DateTime.now();
    final subscription = Subscription(
      id: '',
      userId: userId,
      type: SubscriptionType.free,
      status: SubscriptionStatus.active,
      startDate: now,
      endDate: now.add(const Duration(days: 365 * 10)), // 10 years
      price: 0,
      isActive: true,
      features: {},
    );

    final docRef = await _subscriptionsCollection.add(subscription.toFirestore());
    return subscription.copyWith(id: docRef.id);
  }

  // Start Champions League trial
  Future<Subscription?> startChampionsTrialSubscription() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Check if user already had trial
      final existingSubscriptions = await _subscriptionsCollection
          .where('userId', isEqualTo: currentUser.id)
          .where('type', isEqualTo: 'champions')
          .get();

      for (final doc in existingSubscriptions.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['trialEndDate'] != null) {
          throw Exception('Ви вже використали пробний період');
        }
      }

      // Deactivate current subscription
      await _deactivateCurrentSubscription(currentUser.id);

      // Create trial subscription
      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: 30)); // 30 days trial
      
      final subscription = Subscription(
        id: '',
        userId: currentUser.id,
        type: SubscriptionType.champions,
        status: SubscriptionStatus.trial,
        startDate: now,
        endDate: trialEndDate,
        price: 0,
        isActive: true,
        trialEndDate: trialEndDate,
        features: {},
      );

      final docRef = await _subscriptionsCollection.add(subscription.toFirestore());
      final newSubscription = subscription.copyWith(id: docRef.id);

      // Award trial coins
      await _awardMonthlyCoins(currentUser.id, SubscriptionType.champions);

      return newSubscription;
    } catch (e) {
      print('Error starting trial subscription: $e');
      rethrow;
    }
  }

  // Purchase subscription (mock implementation)
  Future<Subscription?> purchaseSubscription(SubscriptionType type) async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      // Deactivate current subscription
      await _deactivateCurrentSubscription(currentUser.id);

      // Create new subscription
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30)); // 30 days
      
      final subscription = Subscription(
        id: '',
        userId: currentUser.id,
        type: type,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: endDate,
        price: type == SubscriptionType.europa ? 49 : 89,
        isActive: true,
        autoRenew: true,
        features: {},
      );

      final docRef = await _subscriptionsCollection.add(subscription.toFirestore());
      final newSubscription = subscription.copyWith(id: docRef.id);

      // Award monthly coins
      await _awardMonthlyCoins(currentUser.id, type);

      return newSubscription;
    } catch (e) {
      print('Error purchasing subscription: $e');
      rethrow;
    }
  }

  // Deactivate current subscription
  Future<void> _deactivateCurrentSubscription(String userId) async {
    final activeSubscriptions = await _subscriptionsCollection
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in activeSubscriptions.docs) {
      await doc.reference.update({'isActive': false});
    }
  }

  // Award monthly coins based on subscription type
  Future<void> _awardMonthlyCoins(String userId, SubscriptionType type) async {
    int coinsToAward = 0;
    
    switch (type) {
      case SubscriptionType.europa:
        coinsToAward = 30;
        break;
      case SubscriptionType.champions:
        coinsToAward = 60;
        break;
      default:
        return;
    }

    if (coinsToAward > 0) {
      await insertCoinTransaction(
        Supabase.instance.client,
        userId,
        'subscription_bonus',
        coinsToAward,
        tr('il_c4dbbb91b5'),
      );
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      final currentUser = AppAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Користувач не авторизований');
      }

      final subscription = await getUserSubscription(currentUser.id);
      if (subscription == null || subscription.type == SubscriptionType.free) {
        throw Exception('У вас немає активної підписки');
      }

      // Update subscription status
      await _subscriptionsCollection.doc(subscription.id).update({
        'status': 'cancelled',
        'autoRenew': false,
      });

      // Create free subscription
      await _createFreeSubscription(currentUser.id);
    } catch (e) {
      print('Error cancelling subscription: $e');
      rethrow;
    }
  }

  // Check if feature is available for user
  Future<bool> hasFeature(String feature, [String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;

    final subscription = await getUserSubscription(userId);
    return subscription?.hasFeature(feature) ?? false;
  }

  // Get challenge limit for user
  Future<int> getChallengeLimit([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return 1;

    final subscription = await getUserSubscription(userId);
    switch (subscription?.type ?? SubscriptionType.free) {
      case SubscriptionType.champions:
        return -1; // Unlimited
      case SubscriptionType.europa:
        return 5;
      default:
        return 1;
    }
  }

  // Check if user can create more challenges this month
  Future<bool> canCreateChallenge([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;

    final limit = await getChallengeLimit(userId);
    if (limit == -1) return true; // Unlimited

    // Count challenges created this month
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    
    final challengesCount = await _firestore.collection('challenges')
        .where('creatorId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(monthStart))
        .count()
        .get();

    return challengesCount.count! < limit;
  }

  // Get subscription benefits text
  String getSubscriptionBenefits(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return 'Europa League: Розширені можливості, 5 челенджів/місяць, +30 монет';
      case SubscriptionType.champions:
        return 'Champions League: Преміум досвід, необмежені челенджі, +60 монет';
      default:
        return 'Безкоштовна: Базовий функціонал, 1 челендж/місяць';
    }
  }

  // LEGACY METHODS FOR COMPATIBILITY
  Future<Subscription?> getCurrent() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) return null;
    return getUserSubscription(userId);
  }

  Future<void> grantChampionsTrialIfMissing() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) return;
    
    final subscription = await getUserSubscription(userId);
    if (subscription != null && subscription.type != SubscriptionType.free) return;
    
    await startChampionsTrialSubscription();
  }

  Future<Subscription?> getActiveSubscription() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) return null;
    return getUserSubscription(userId);
  }
}