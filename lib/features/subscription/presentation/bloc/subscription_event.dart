import 'package:equatable/equatable.dart';
import 'package:flap_app/models/subscription.dart';

sealed class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionStarted extends SubscriptionEvent {
  const SubscriptionStarted();
}

class SubscriptionRefreshed extends SubscriptionEvent {
  const SubscriptionRefreshed();
}

class SubscriptionPurchaseRequested extends SubscriptionEvent {
  const SubscriptionPurchaseRequested(this.type);

  final SubscriptionType type;

  @override
  List<Object?> get props => [type];
}

class SubscriptionTrialRequested extends SubscriptionEvent {
  const SubscriptionTrialRequested();
}

class SubscriptionCancelRequested extends SubscriptionEvent {
  const SubscriptionCancelRequested();
}
