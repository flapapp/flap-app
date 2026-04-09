import '../repositories/subscription_repository.dart';

class CancelSubscriptionUseCase {
  const CancelSubscriptionUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<void> call() {
    return _repository.cancelSubscription();
  }
}
