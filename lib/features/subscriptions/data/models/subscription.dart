import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/subscription_entity.dart';

export '../../domain/entities/subscription_entity.dart';

part 'subscription.g.dart';

@JsonSerializable(explicitToJson: true)
class Subscription extends SubscriptionEntity {
  const Subscription({
    required super.id,
    required super.userId,
    required super.type,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.price,
    super.isActive = true,
    super.trialEndDate,
    super.autoRenew = false,
    required super.features,
  });

  factory Subscription.fromSupabase({
    required Map<String, dynamic> row,
    required String planCode,
  }) {
    DateTime parseDate(String key) {
      final raw = row[key];
      if (raw == null) return DateTime.now();
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(String key) {
      final raw = row[key];
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString());
    }

    return Subscription(
      id: (row['id'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      type: SubscriptionType.values.firstWhere(
        (e) => e.toString().split('.').last == planCode,
        orElse: () => SubscriptionType.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (row['status'] ?? 'expired'),
        orElse: () => SubscriptionStatus.expired,
      ),
      startDate: parseDate('starts_at'),
      endDate: parseDate('ends_at'),
      price: ((row['subscription_plans'] as Map<String, dynamic>?)?['price_monthly']
                  as num?)
              ?.toInt() ??
          0,
      isActive: ((row['status'] ?? '').toString() == 'active') ||
          ((row['status'] ?? '').toString() == 'trial'),
      trialEndDate: parseNullableDate('trial_ends_at'),
      autoRenew: row['auto_renew'] == true,
      features: const <String, dynamic>{},
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  // Convert to Map for Supabase subscriptions table
  Map<String, dynamic> toSupabase(String planId) {
    return {
      'user_id': userId,
      'plan_id': planId,
      'status': status.toString().split('.').last,
      'starts_at': startDate.toUtc().toIso8601String(),
      'ends_at': endDate.toUtc().toIso8601String(),
      'trial_ends_at': trialEndDate?.toUtc().toIso8601String(),
      'auto_renew': autoRenew,
    };
  }

  // Subscription info
  String get name {
    return _getLocalizedName(type);
  }

  static String _getLocalizedName(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return 'Europa League';
      case SubscriptionType.champions:
        return 'Champions League';
      default:
        return tr('il_f411a1fb62');
    }
  }

  String get description {
    return _getLocalizedDescription(type);
  }

  static String _getLocalizedDescription(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return tr('il_32ba7323a7');
      case SubscriptionType.champions:
        return tr('il_7132e3d7a7');
      default:
        return tr('il_d345e00054');
    }
  }

  int get monthlyPrice {
    switch (type) {
      case SubscriptionType.europa:
        return 49;
      case SubscriptionType.champions:
        return 89;
      default:
        return 0;
    }
  }

  List<String> get featuresList {
    return _getLocalizedFeaturesList(type);
  }

  static List<String> _getLocalizedFeaturesList(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return [
          tr('il_f2f4f86869'),
          tr('il_dc674ca73a'),
          tr('il_b04fa216ad'),
          tr('il_b30a0e36fb'),
          tr('il_fc39298e1f'),
          tr('il_7adcd6836d'),
        ];
      case SubscriptionType.champions:
        return [
          tr('il_1042932b5f'),
          tr('il_19c8cd536b'),
          tr('il_4b497c5b9c'),
          tr('il_9f37ff73d7'),
          tr('il_98d22bd207'),
          tr('il_2eae371829'),
          tr('il_ee166fb067'),
          tr('il_713b30da5a'),
        ];
      default:
        return [
          tr('il_fcf2dcb27a'),
          tr('il_2b49688a56'),
          tr('il_1d741d8cfc'),
          tr('il_7f19034ddd'),
        ];
    }
  }

  bool get isTrialAvailable {
    return type == SubscriptionType.champions && trialEndDate == null;
  }

  bool get isInTrial {
    return status == SubscriptionStatus.trial && 
           trialEndDate != null && 
           trialEndDate!.isAfter(DateTime.now());
  }

  int get daysLeft {
    if (!isActive) return 0;
    final targetDate = isInTrial ? trialEndDate! : endDate;
    return targetDate.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  // Check if user has specific feature
  bool hasFeature(String feature) {
    switch (type) {
      case SubscriptionType.champions:
        return true; // Champions має всі можливості
      case SubscriptionType.europa:
        return [
          'visible_ratings',
          'comments',
          'extended_filters',
          'blue_badge',
          'monthly_coins',
          'challenge_limit_5',
        ].contains(feature);
      default:
        return [
          'basic_functionality',
          'challenge_limit_1',
        ].contains(feature);
    }
  }

  // Copy with changes
  Subscription copyWith({
    String? id,
    String? userId,
    SubscriptionType? type,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? price,
    bool? isActive,
    DateTime? trialEndDate,
    bool? autoRenew,
    Map<String, dynamic>? features,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      price: price ?? this.price,
      isActive: isActive ?? this.isActive,
      trialEndDate: trialEndDate ?? this.trialEndDate,
      autoRenew: autoRenew ?? this.autoRenew,
      features: features ?? this.features,
    );
  }
}