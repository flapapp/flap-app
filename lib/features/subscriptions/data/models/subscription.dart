import 'package:json_annotation/json_annotation.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/subscription_entity.dart';

export '../../domain/entities/subscription_entity.dart';

part 'subscription.g.dart';

/// Display price of the premium plan, in whole US dollars.
const int kPremiumMonthlyPrice = 1;
const int kPremiumYearlyPrice = 10;

/// Length of the free trial offered on the premium plan.
const int kTrialDurationDays = 21;

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
    super.billingInterval,
    super.paddleSubscriptionId,
    super.currentPeriodEnd,
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

    final statusRaw = (row['status'] ?? 'expired').toString();
    final billingRaw = row['billing_interval']?.toString();

    return Subscription(
      id: (row['id'] ?? '').toString(),
      userId: (row['user_id'] ?? '').toString(),
      type: planCode == 'premium'
          ? SubscriptionType.premium
          : SubscriptionType.free,
      status: _statusFromString(statusRaw),
      startDate: parseDate('starts_at'),
      endDate: parseDate('ends_at'),
      price: ((row['subscription_plans'] as Map<String, dynamic>?)?['price_monthly']
                  as num?)
              ?.toInt() ??
          0,
      isActive: statusRaw == 'active' || statusRaw == 'trial',
      trialEndDate: parseNullableDate('trial_ends_at'),
      autoRenew: row['auto_renew'] == true,
      billingInterval: billingRaw == 'yearly'
          ? BillingInterval.yearly
          : billingRaw == 'monthly'
              ? BillingInterval.monthly
              : null,
      paddleSubscriptionId: row['paddle_subscription_id']?.toString(),
      currentPeriodEnd: parseNullableDate('current_period_end'),
      features: const <String, dynamic>{},
    );
  }

  static SubscriptionStatus _statusFromString(String raw) {
    switch (raw) {
      case 'active':
        return SubscriptionStatus.active;
      case 'trial':
        return SubscriptionStatus.trial;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      default:
        return SubscriptionStatus.expired;
    }
  }

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  // Convert to Map for the Supabase subscriptions table.
  Map<String, dynamic> toSupabase(String planId) {
    return {
      'user_id': userId,
      'plan_id': planId,
      'status': _statusToString(status),
      'starts_at': startDate.toUtc().toIso8601String(),
      'ends_at': endDate.toUtc().toIso8601String(),
      'trial_ends_at': trialEndDate?.toUtc().toIso8601String(),
      'auto_renew': autoRenew,
      if (billingInterval != null)
        'billing_interval':
            billingInterval == BillingInterval.yearly ? 'yearly' : 'monthly',
      if (paddleSubscriptionId != null)
        'paddle_subscription_id': paddleSubscriptionId,
      if (currentPeriodEnd != null)
        'current_period_end': currentPeriodEnd!.toUtc().toIso8601String(),
    };
  }

  static String _statusToString(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.pastDue:
        return 'past_due';
      case SubscriptionStatus.active:
        return 'active';
      case SubscriptionStatus.trial:
        return 'trial';
      case SubscriptionStatus.cancelled:
        return 'cancelled';
      case SubscriptionStatus.expired:
        return 'expired';
    }
  }

  // --- Display helpers -------------------------------------------------------

  String get name => type == SubscriptionType.premium
      ? tr('subscription_premium_name')
      : tr('subscription_free_name');

  String get description => type == SubscriptionType.premium
      ? tr('subscription_premium_desc')
      : tr('subscription_free_desc');

  int get monthlyPrice =>
      type == SubscriptionType.premium ? kPremiumMonthlyPrice : 0;

  List<String> get featuresList => type == SubscriptionType.premium
      ? [
          tr('subscription_feature_create'),
          tr('subscription_feature_rate'),
          tr('subscription_feature_join'),
          tr('subscription_feature_interact'),
          tr('subscription_feature_challenges'),
        ]
      : [
          tr('subscription_feature_browse'),
          tr('subscription_feature_profiles'),
          tr('subscription_feature_leaderboards'),
        ];

  /// True while the subscription currently grants premium access.
  ///
  /// A paid `active` plan always grants access; a `trial` grants access only
  /// while it hasn't lapsed. The date check is what blocks activities the moment
  /// the signup trial's window closes (the nightly cron flips the row to
  /// `expired` afterwards, but access must end immediately — not on the next
  /// cron run).
  bool get isPremiumActive =>
      type == SubscriptionType.premium &&
      (status == SubscriptionStatus.active ||
          (status == SubscriptionStatus.trial &&
              trialEndDate != null &&
              trialEndDate!.isAfter(DateTime.now())));

  bool get isInTrial =>
      status == SubscriptionStatus.trial &&
      trialEndDate != null &&
      trialEndDate!.isAfter(DateTime.now());

  bool get isPastDue => status == SubscriptionStatus.pastDue;

  /// Days remaining in the current access window (trial or paid period).
  int get daysLeft {
    if (!isPremiumActive) return 0;
    final target = isInTrial ? trialEndDate! : (currentPeriodEnd ?? endDate);
    return target.difference(DateTime.now()).inDays.clamp(0, 9999);
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
    BillingInterval? billingInterval,
    String? paddleSubscriptionId,
    DateTime? currentPeriodEnd,
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
      billingInterval: billingInterval ?? this.billingInterval,
      paddleSubscriptionId: paddleSubscriptionId ?? this.paddleSubscriptionId,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      features: features ?? this.features,
    );
  }
}
