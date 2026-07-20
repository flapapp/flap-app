import '../../data/models/subscription.dart';

/// Read access to the current user's subscription state. Premium is granted
/// server-side (Paddle webhook); the client only reads status and can soft-
/// cancel (turn off auto-renew).
abstract class SubscriptionsRepository {
  Future<Subscription?> getUserSubscription(String userId);

  Future<bool> hasActiveSubscription([String? userId]);

  Future<SubscriptionType> getSubscriptionType([String? userId]);

  Future<void> cancelSubscription();
}
