import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../../utils/i18n.dart';
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
        return I18n.inline('Безкоштовна', 'Free');
    }
  }

  String get description {
    return _getLocalizedDescription(type);
  }

  static String _getLocalizedDescription(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return I18n.inline('Розширені можливості для серйозних гравців', 'Extended features for serious players');
      case SubscriptionType.champions:
        return I18n.inline('Преміум досвід для справжніх чемпіонів', 'Premium experience for true champions');
      default:
        return I18n.inline('Базові можливості FLAP', 'Basic FLAP features');
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
          I18n.inline('Видимий рейтинг всіх гравців', 'Visible ratings of all players'),
          I18n.inline('5 челенджів на місяць', '5 challenges per month'),
          I18n.inline('+30 монет щомісяця', '+30 coins monthly'),
          I18n.inline('Коментарі до відео', 'Video comments'),
          I18n.inline('Додаткові фільтри пошуку', 'Additional search filters'),
          I18n.inline('Синя позначка біля імені', 'Blue badge next to name'),
        ];
      case SubscriptionType.champions:
        return [
          I18n.inline('Все з Europa League', 'Everything from Europa League'),
          I18n.inline('Необмежені челенджі', 'Unlimited challenges'),
          I18n.inline('+60 монет щомісяця', '+60 coins monthly'),
          I18n.inline('Знижка 20% на монети', '20% discount on coins'),
          I18n.inline('Приватні матчі', 'Private matches'),
          I18n.inline('Детальна статистика', 'Detailed statistics'),
          I18n.inline('Золота позначка біля імені', 'Gold badge next to name'),
          I18n.inline('VIP підтримка', 'VIP support'),
        ];
      default:
        return [
          I18n.inline('Базовий функціонал', 'Basic functionality'),
          I18n.inline('1 челендж на місяць', '1 challenge per month'),
          I18n.inline('Рейтинги інших гравців приховані', 'Other players ratings are hidden'),
          I18n.inline('Обмежені фільтри', 'Limited filters'),
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