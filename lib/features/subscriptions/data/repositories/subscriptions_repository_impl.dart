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
  Stream<Subscription?> getUserSubscriptionStream(String userId) {
    return _service.getUserSubscriptionStream(userId);
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
  Future<Subscription?> startChampionsTrialSubscription() {
    return _service.startChampionsTrialSubscription();
  }

  @override
  Future<Subscription?> purchaseSubscription(SubscriptionType type) {
    return _service.purchaseSubscription(type);
  }

  @override
  Future<void> cancelSubscription() {
    return _service.cancelSubscription();
  }

  @override
  Future<bool> hasFeature(String feature, [String? userId]) {
    return _service.hasFeature(feature, userId);
  }

  @override
  Future<int> getChallengeLimit([String? userId]) {
    return _service.getChallengeLimit(userId);
  }

  @override
  Future<bool> canCreateChallenge([String? userId]) {
    return _service.canCreateChallenge(userId);
  }

  @override
  String getSubscriptionBenefits(SubscriptionType type) {
    return _service.getSubscriptionBenefits(type);
  }

  @override
  Future<Subscription?> getCurrent() {
    return _service.getCurrent();
  }

  @override
  Future<void> grantChampionsTrialIfMissing() {
    return _service.grantChampionsTrialIfMissing();
  }

  @override
  Future<Subscription?> getActiveSubscription() {
    return _service.getActiveSubscription();
  }
}
