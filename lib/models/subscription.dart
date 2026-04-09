import 'package:flap_app/utils/i18n.dart';

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
  final int price;
  final bool isActive;
  final DateTime? trialEndDate;
  final bool autoRenew;
  final Map<String, dynamic> features;
  /// Mirrors `profiles.champions_trial_used` (Supabase).
  final bool championsTrialConsumed;

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
    this.championsTrialConsumed = false,
  });

  static SubscriptionType typeFromDb(String? raw) {
    final s = (raw ?? 'free').toString().toLowerCase();
    if (s == 'europa' || s == 'europa_league') {
      return SubscriptionType.europa;
    }
    if (s == 'champions' || s == 'champions_league') {
      return SubscriptionType.champions;
    }
    return SubscriptionType.free;
  }

  static String typeToDb(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.europa:
        return 'europa';
      case SubscriptionType.champions:
        return 'champions';
      case SubscriptionType.free:
        return 'free';
    }
  }

  static SubscriptionStatus statusFromDb(String? raw) {
    switch (raw) {
      case 'trial':
        return SubscriptionStatus.trial;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'active':
        return SubscriptionStatus.active;
      default:
        return SubscriptionStatus.active;
    }
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      return DateTime.tryParse(v)?.toLocal();
    }
    return null;
  }

  factory Subscription.fromProfileRow(
    Map<String, dynamic> row, {
    required String userId,
  }) {
    final id = userId;
    final type = typeFromDb(row['subscription']?.toString());
    var status = statusFromDb(row['subscription_status']?.toString());
    final start = _parseTs(row['subscription_started_at']) ?? DateTime.now();
    var end = _parseTs(row['subscription_expiry']) ??
        DateTime.now().add(const Duration(days: 365 * 10));
    final trialEnd = _parseTs(row['subscription_trial_end']);
    final active = row['subscription_active'] == true;
    final auto = row['subscription_auto_renew'] == true;
    final priceVal = (row['subscription_price'] as num?)?.toInt() ?? 0;
    final trialUsed = row['champions_trial_used'] == true;

    if (status == SubscriptionStatus.trial &&
        trialEnd != null &&
        !trialEnd.isAfter(DateTime.now())) {
      status = SubscriptionStatus.expired;
    }

    return Subscription(
      id: id,
      userId: userId,
      type: type,
      status: status,
      startDate: start,
      endDate: end,
      price: priceVal,
      isActive: active,
      trialEndDate: trialEnd,
      autoRenew: auto,
      features: const {},
      championsTrialConsumed: trialUsed,
    );
  }

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
        return I18n.inline(
          'Розширені можливості для серйозних гравців',
          'Extended features for serious players',
        );
      case SubscriptionType.champions:
        return I18n.inline(
          'Преміум досвід для справжніх чемпіонів',
          'Premium experience for true champions',
        );
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
          I18n.inline(
            'Видимий рейтинг всіх гравців',
            'Visible ratings of all players',
          ),
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
          I18n.inline(
            'Рейтинги інших гравців приховані',
            'Other players ratings are hidden',
          ),
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

  bool hasFeature(String feature) {
    switch (type) {
      case SubscriptionType.champions:
        return true;
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
    bool? championsTrialConsumed,
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
      championsTrialConsumed:
          championsTrialConsumed ?? this.championsTrialConsumed,
    );
  }
}
