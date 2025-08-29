import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionType {
  free,
  europa,
  champions,
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  trial,
}

class Subscription {
  final String id;
  final String userId;
  final SubscriptionType type;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime endDate;
  final int price; // В гривнях
  final bool isActive;
  final DateTime? trialEndDate;
  final bool autoRenew;
  final Map<String, dynamic> features;

  Subscription({
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
    switch (type) {
      case SubscriptionType.europa:
        return 'Europa League';
      case SubscriptionType.champions:
        return 'Champions League';
      default:
        return 'Безкоштовна';
    }
  }

  String get description {
    switch (type) {
      case SubscriptionType.europa:
        return 'Розширені можливості для серйозних гравців';
      case SubscriptionType.champions:
        return 'Преміум досвід для справжніх чемпіонів';
      default:
        return 'Базові можливості FLAP';
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
    switch (type) {
      case SubscriptionType.europa:
        return [
          'Видимий рейтинг всіх гравців',
          '5 челенджів на місяць',
          '+30 монет щомісяця',
          'Коментарі до відео',
          'Додаткові фільтри пошуку',
          'Синя позначка біля імені',
        ];
      case SubscriptionType.champions:
        return [
          'Все з Europa League',
          'Необмежені челенджі',
          '+60 монет щомісяця',
          'Знижка 20% на монети',
          'Приватні матчі',
          'Детальна статистика',
          'Золота позначка біля імені',
          'VIP підтримка',
        ];
      default:
        return [
          'Базовий функціонал',
          '1 челендж на місяць',
          'Рейтинги інших гравців приховані',
          'Обмежені фільтри',
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