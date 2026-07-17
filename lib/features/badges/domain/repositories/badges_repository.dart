import '../../data/models/badge.dart';

/// Badge catalog, ownership, purchases, and activity awards (domain).
abstract class BadgesRepository {
  Future<List<Badge>> getAvailableBadges();

  Future<List<String>> getUserBadgeIds(String userId);

  Future<bool> userOwnsBadge(String userId, String badgeId);

  Future<bool> purchaseBadge(String badgeId);

  Future<void> initializeDefaultBadges();

  Future<bool> awardBadge(String userId, String badgeId, String reason);

  Future<Badge?> getBadge(String badgeId);

  Future<List<Badge>> getUserBadgeObjects(String userId);

  List<String> getBadgeCategories();

  String getCategoryDisplayName(String category);

  Future<void> checkAndAwardActivityBadges(String userId);
}
