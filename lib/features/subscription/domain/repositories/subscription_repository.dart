import 'package:flap_app/models/subscription.dart';

abstract class SubscriptionRepository {
  Future<Subscription?> getUserSubscription(String userId);

  Stream<Subscription?> watchUserSubscription(String userId);

  Future<bool> hasActiveSubscription([String? userId]);

  Future<SubscriptionType> getSubscriptionType([String? userId]);

  Future<Subscription?> startChampionsTrialSubscription();

  Future<Subscription?> purchaseSubscription(SubscriptionType type);

  Future<void> cancelSubscription();

  Future<bool> hasFeature(String feature, [String? userId]);

  Future<int> getChallengeLimit([String? userId]);

  Future<bool> canCreateChallenge([String? userId]);

  String getSubscriptionBenefits(SubscriptionType type);

  Future<Subscription?> getCurrent();

  Future<void> grantChampionsTrialIfMissing();

  Future<Subscription?> getActiveSubscription();
}
