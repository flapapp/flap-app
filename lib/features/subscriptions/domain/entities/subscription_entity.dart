import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum SubscriptionType {
  free,
  europa,
  champions,
}

@JsonEnum()
enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  trial,
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
        features,
      ];
}
