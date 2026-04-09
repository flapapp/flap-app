import 'package:flap_app/models/badge.dart';

/// Badges catalog, ownership, purchases, and activity awards (Supabase).
abstract class BadgeRepository {
  /// Upserts [Badge.getDefaultBadges] into `public.badges`.
  Future<void> initializeDefaultBadges();

  Future<List<Badge>> getAvailableBadges();

  Future<List<Badge>> getBadgesByCategory(String category);

  Future<List<String>> getUserBadgeIds(String userId);

  Future<bool> userOwnsBadge(String userId, String badgeId);

  /// Throws [BadgeFailure] on business errors.
  Future<void> purchaseBadge(String badgeId);

  Future<bool> awardBadge(String userId, String badgeId, String reason);

  Future<Badge?> getBadge(String badgeId);

  Future<List<Badge>> getUserBadgeObjects(String userId);

  Future<int> getUserCoins(String userId);

  List<String> getBadgeCategories();

  String getCategoryDisplayName(String category);

  Future<void> checkAndAwardActivityBadges(String userId);
}
