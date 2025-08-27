import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _subs => _firestore.collection('subscriptions');
  CollectionReference get _subscriptionsCollection => _firestore.collection('subscriptions');

  Future<Subscription?> getCurrent() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    
    // Simple query without orderBy to avoid composite index
    final docs = await _subs.where('userId', isEqualTo: uid).get();
    if (docs.docs.isEmpty) return null;
    
    // Sort on client side and return the most recent
    final subscriptions = docs.docs.map((doc) => Subscription.fromFirestore(doc)).toList();
    subscriptions.sort((a, b) => b.endAt.compareTo(a.endAt));
    
    return subscriptions.first;
  }

  Future<void> grantChampionsTrialIfMissing() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final existing = await getCurrent();
    if (existing != null && existing.isActive) return;

    final now = DateTime.now();
    final trial = Subscription(
      userId: uid,
      plan: SubscriptionPlan.champions,
      startAt: now,
      endAt: now.add(const Duration(days: 30)),
    );

    // Save subscription doc and user perks
    final batch = _firestore.batch();
    final docRef = _subs.doc();
    batch.set(docRef, trial.toFirestore());
    batch.update(_firestore.collection('users').doc(uid), {
      'subscriptionActive': true,
      'subscriptionPlan': 'champions',
      'maxChallengesPerMonth': 9999,
      'perks': {
        'unlimitedChallenges': true,
        'priorityBadges': true,
      },
    });
    await batch.commit();
  }

  // Get active subscription (simplified query to avoid index issues)
  Future<Subscription?> getActiveSubscription() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      // Simple query without composite index - just get all user subscriptions
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Filter and find active subscription on client side
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final endAt = (data['endAt'] as Timestamp).toDate();
          if (endAt.isAfter(DateTime.now())) {
            return Subscription.fromFirestore(doc);
          }
        } catch (e) {
          print('Error parsing subscription ${doc.id}: $e');
          continue;
        }
      }

      return null;
    } catch (e) {
      print('Error getting active subscription: $e');
      return null;
    }
  }
}


