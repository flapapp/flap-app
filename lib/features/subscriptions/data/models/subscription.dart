import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Factory constructor from Firestore
  factory Subscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Subscription(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: SubscriptionType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => SubscriptionType.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => SubscriptionStatus.expired,
      ),
      startDate: data['startDate'] != null 
          ? (data['startDate'] as Timestamp).toDate() 
          : DateTime.now(),
      endDate: data['endDate'] != null 
          ? (data['endDate'] as Timestamp).toDate() 
          : DateTime.now(),
      price: data['price'] ?? 0,
      isActive: data['isActive'] ?? false,
      trialEndDate: data['trialEndDate'] != null 
          ? (data['trialEndDate'] as Timestamp).toDate() 
          : null,
      autoRenew: data['autoRenew'] ?? false,
      features: Map<String, dynamic>.from(data['features'] ?? {}),
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'price': price,
      'isActive': isActive,
      'trialEndDate': trialEndDate != null 
          ? Timestamp.fromDate(trialEndDate!) 
          : null,
      'autoRenew': autoRenew,
      'features': features,
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