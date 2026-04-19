import '../../../badges/data/models/badge.dart' as app_badge;

abstract class UserBadgesRepository {
  Future<List<app_badge.Badge>> getUserBadges(String userId);
}
