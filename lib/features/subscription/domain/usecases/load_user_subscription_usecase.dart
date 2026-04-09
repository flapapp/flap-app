import 'package:flap_app/models/subscription.dart';

import '../repositories/subscription_repository.dart';

class LoadUserSubscriptionUseCase {
  const LoadUserSubscriptionUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<Subscription?> call(String userId) {
    return _repository.getUserSubscription(userId);
  }
}
