import 'package:flap_app/models/badge.dart';

import '../../domain/repositories/badge_repository.dart';
import '../datasources/badge_remote_data_source.dart';

class BadgeRepositoryImpl implements BadgeRepository {
  BadgeRepositoryImpl(this._remote);

  final BadgeRemoteDataSource _remote;

  /// Matches legacy [BadgeService] behavior: one in-flight seed, shared awaiters.
  static Future<void>? _initializeFuture;

  @override
  Future<void> initializeDefaultBadges() async {
    _initializeFuture ??= () async {
      final rows = Badge.getDefaultBadges().map((b) => b.toJson()).toList();
      await _remote.upsertDefaultBadges(rows);
    }();
    try {
      await _initializeFuture;
    } catch (_) {
      _initializeFuture = null;
      rethrow;
    }
  }

  @override
  Future<List<Badge>> getAvailableBadges() async {
    final rows = await _remote.fetchAvailableBadges();
    return rows.map(_rowToBadge).map(_resolveEffectiveBadgePrice).toList();
  }

  @override
  Future<List<Badge>> getBadgesByCategory(String category) async {
    final rows = await _remote.fetchBadgesByCategory(category);
    return rows.map(_rowToBadge).map(_resolveEffectiveBadgePrice).toList();
  }

  @override
  Future<List<String>> getUserBadgeIds(String userId) {
    return _remote.fetchUserBadgeIds(userId);
  }

  @override
  Future<bool> userOwnsBadge(String userId, String badgeId) async {
    final ids = await getUserBadgeIds(userId);
    return ids.contains(badgeId);
  }

  @override
  Future<void> purchaseBadge(String badgeId) async {
    await _remote.rpcPurchaseBadge(badgeId);
  }

  @override
  Future<bool> awardBadge(String userId, String badgeId, String reason) async {
    try {
      return await _remote.rpcAwardBadge(
        userId: userId,
        badgeId: badgeId,
        reason: reason,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Badge?> getBadge(String badgeId) async {
    final row = await _remote.fetchBadgeRow(badgeId);
    if (row == null) return null;
    return _resolveEffectiveBadgePrice(_rowToBadge(row));
  }

  @override
  Future<List<Badge>> getUserBadgeObjects(String userId) async {
    final badgeIds = await getUserBadgeIds(userId);
    final badges = <Badge>[];
    for (final id in badgeIds) {
      final b = await getBadge(id);
      if (b != null) {
        badges.add(b);
      }
    }
    return badges;
  }

  @override
  Future<int> getUserCoins(String userId) => _remote.fetchUserCoins(userId);

  @override
  List<String> getBadgeCategories() {
    return ['starter', 'skill', 'achievement', 'legendary', 'special'];
  }

  @override
  String getCategoryDisplayName(String category) {
    switch (category) {
      case 'starter':
        return 'Початкові';
      case 'skill':
        return 'Навички';
      case 'achievement':
        return 'Досягнення';
      case 'legendary':
        return 'Легендарні';
      case 'special':
        return 'Спеціальні';
      default:
        return 'Інші';
    }
  }

  @override
  Future<void> checkAndAwardActivityBadges(String userId) async {
    try {
      final row = await _remote.fetchProfileActivityRow(userId);
      if (row == null) return;

      // Legacy Firestore used `friendsCount` on the user doc; keep `friends_count`
      // in sync with friend accept flows for social badge unlocks.
      final friendsCount = (row['friends_count'] as num?)?.toInt() ?? 0;
      // Legacy used `stats.matchesPlayed`; profiles mirror `matches` / `total_matches`.
      final m = (row['matches'] as num?)?.toInt() ?? 0;
      final tm = (row['total_matches'] as num?)?.toInt() ?? 0;
      final matchesPlayed = m >= tm ? m : tm;
      final avgVideoRating = (row['video_rating'] as num?)?.toDouble() ?? 0.0;

      if (!await userOwnsBadge(userId, 'rookie')) {
        await awardBadge(userId, 'rookie', 'Перший крок у FLAP');
      }

      if (friendsCount >= 5 && !await userOwnsBadge(userId, 'social')) {
        await awardBadge(userId, 'social', '5+ друзів');
      }

      if (matchesPlayed >= 50 && !await userOwnsBadge(userId, 'veteran')) {
        await awardBadge(userId, 'veteran', '50+ матчів');
      }

      if (avgVideoRating >= 4.0 && !await userOwnsBadge(userId, 'skillful')) {
        await awardBadge(
          userId,
          'skillful',
          'Середня оцінка відео 4.0+',
        );
      }
    } catch (_) {
      // Preserve legacy behavior: swallow errors from activity checks.
    }
  }

  Badge _rowToBadge(Map<String, dynamic> row) {
    return Badge.fromJson(Map<String, dynamic>.from(row));
  }

  Badge _resolveEffectiveBadgePrice(Badge badge) {
    for (final defaultBadge in Badge.getDefaultBadges()) {
      if (defaultBadge.id == badge.id) {
        return badge.copyWith(price: defaultBadge.price);
      }
    }
    return badge;
  }
}
