import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../../domain/repositories/subscriptions_repository.dart';

class SubscriptionsRepositoryImpl implements SubscriptionsRepository {
  SubscriptionsRepositoryImpl(this._service);

  final SubscriptionService _service;

  @override
  Future<Subscription?> getUserSubscription(String userId) {
    return _service.getUserSubscription(userId);
  }

  @override
  Future<bool> hasActiveSubscription([String? userId]) {
    return _service.hasActiveSubscription(userId);
  }

  @override
  Future<SubscriptionType> getSubscriptionType([String? userId]) {
    return _service.getSubscriptionType(userId);
  }

  @override
  Future<void> cancelSubscription() {
    return _service.cancelSubscription();
  }
}
