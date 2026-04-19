// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) => Subscription(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: $enumDecode(_$SubscriptionTypeEnumMap, json['type']),
      status: $enumDecode(_$SubscriptionStatusEnumMap, json['status']),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      price: (json['price'] as num).toInt(),
      isActive: json['isActive'] as bool? ?? true,
      trialEndDate: json['trialEndDate'] == null
          ? null
          : DateTime.parse(json['trialEndDate'] as String),
      autoRenew: json['autoRenew'] as bool? ?? false,
      features: json['features'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'type': _$SubscriptionTypeEnumMap[instance.type]!,
      'status': _$SubscriptionStatusEnumMap[instance.status]!,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate.toIso8601String(),
      'price': instance.price,
      'isActive': instance.isActive,
      'trialEndDate': instance.trialEndDate?.toIso8601String(),
      'autoRenew': instance.autoRenew,
      'features': instance.features,
    };

const _$SubscriptionTypeEnumMap = {
  SubscriptionType.free: 'free',
  SubscriptionType.europa: 'europa',
  SubscriptionType.champions: 'champions',
};

const _$SubscriptionStatusEnumMap = {
  SubscriptionStatus.active: 'active',
  SubscriptionStatus.expired: 'expired',
  SubscriptionStatus.cancelled: 'cancelled',
  SubscriptionStatus.trial: 'trial',
};
