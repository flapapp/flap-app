import '../../../../models/badge.dart';
import '../../../../services/badge_service.dart';
import '../../domain/repositories/badges_repository.dart';

class BadgesRepositoryImpl implements BadgesRepository {
  BadgesRepositoryImpl(this._badges);

  final BadgeService _badges;

  @override
  Stream<List<Badge>> getAvailableBadges() {
    return _badges.getAvailableBadges();
  }

  @override
  Stream<List<Badge>> getBadgesByCategory(String category) {
    return _badges.getBadgesByCategory(category);
  }

  @override
  Future<List<String>> getUserBadgeIds(String userId) {
    return _badges.getUserBadges(userId);
  }

  @override
  Future<bool> userOwnsBadge(String userId, String badgeId) {
    return _badges.userOwnsBadge(userId, badgeId);
  }

  @override
  Future<bool> purchaseBadge(String badgeId) {
    return _badges.purchaseBadge(badgeId);
  }

  @override
  Future<void> initializeDefaultBadges() {
    return _badges.initializeDefaultBadges();
  }

  @override
  Future<bool> awardBadge(String userId, String badgeId, String reason) {
    return _badges.awardBadge(userId, badgeId, reason);
  }

  @override
  Future<Badge?> getBadge(String badgeId) {
    return _badges.getBadge(badgeId);
  }

  @override
  Future<List<Badge>> getUserBadgeObjects(String userId) {
    return _badges.getUserBadgeObjects(userId);
  }

  @override
  List<String> getBadgeCategories() {
    return _badges.getBadgeCategories();
  }

  @override
  String getCategoryDisplayName(String category) {
    return _badges.getCategoryDisplayName(category);
  }

  @override
  Future<void> checkAndAwardActivityBadges(String userId) {
    return _badges.checkAndAwardActivityBadges(userId);
  }
}
