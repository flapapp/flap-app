import 'package:flap_app/models/subscription.dart';

import '../repositories/subscription_repository.dart';

class PurchaseSubscriptionUseCase {
  const PurchaseSubscriptionUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<Subscription?> call(SubscriptionType type) {
    return _repository.purchaseSubscription(type);
  }
}
