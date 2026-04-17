import '../../../../models/badge.dart' as app_badge;
import '../../../../services/badge_service.dart';
import '../../domain/repositories/user_badges_repository.dart';

class UserBadgesRepositoryImpl implements UserBadgesRepository {
  UserBadgesRepositoryImpl(this._badges);

  final BadgeService _badges;

  @override
  Future<List<app_badge.Badge>> getUserBadges(String userId) {
    return _badges.getUserBadgeObjects(userId);
  }
}
