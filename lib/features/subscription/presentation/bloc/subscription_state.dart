import 'package:equatable/equatable.dart';
import 'package:flap_app/models/subscription.dart';

sealed class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

class SubscriptionLoadInProgress extends SubscriptionState {
  const SubscriptionLoadInProgress();
}

class SubscriptionReady extends SubscriptionState {
  const SubscriptionReady(this.current);

  final Subscription? current;

  @override
  List<Object?> get props => [current];
}

class SubscriptionFailure extends SubscriptionState {
  const SubscriptionFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
