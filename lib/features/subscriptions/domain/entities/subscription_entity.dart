import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

/// The app now has a single paid plan. [free] users get view-only access;
/// [premium] users (whether trialing or paying) get full access.
@JsonEnum()
enum SubscriptionType {
  free,
  premium,
}

/// Lifecycle states, mirrored from Paddle via the webhook.
///
/// - [trial]/[active] mean the user currently has premium access.
/// - [pastDue] means a renewal payment failed; access is treated as lapsed
///   until Paddle recovers the payment (the webhook flips it back to active).
/// - [expired]/[cancelled] mean no access.
@JsonEnum()
enum SubscriptionStatus {
  active,
  trial,
  @JsonValue('past_due')
  pastDue,
  expired,
  cancelled,
}

/// How a premium subscription is billed.
@JsonEnum()
enum BillingInterval {
  monthly,
  yearly,
}

class SubscriptionEntity extends Equatable {
  const SubscriptionEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.price,
    this.isActive = true,
    this.trialEndDate,
    this.autoRenew = false,
    this.billingInterval,
    this.paddleSubscriptionId,
    this.currentPeriodEnd,
    required this.features,
  });

  final String id;
  final String userId;
  final SubscriptionType type;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final int price;
  final bool isActive;
  final DateTime? trialEndDate;
  final bool autoRenew;
  final BillingInterval? billingInterval;
  final String? paddleSubscriptionId;
  final DateTime? currentPeriodEnd;
  final Map<String, dynamic> features;

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        status,
        startDate,
        endDate,
        price,
        isActive,
        trialEndDate,
        autoRenew,
        billingInterval,
        paddleSubscriptionId,
        currentPeriodEnd,
        features,
      ];
}
