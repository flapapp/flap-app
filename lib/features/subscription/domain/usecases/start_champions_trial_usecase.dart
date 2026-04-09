import 'package:flap_app/models/subscription.dart';

import '../repositories/subscription_repository.dart';

class StartChampionsTrialUseCase {
  const StartChampionsTrialUseCase(this._repository);

  final SubscriptionRepository _repository;

  Future<Subscription?> call() {
    return _repository.startChampionsTrialSubscription();
  }
}
