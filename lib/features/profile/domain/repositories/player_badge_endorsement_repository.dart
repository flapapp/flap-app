import '../../../../core/error/result.dart';
import '../../../../core/common/unit.dart';

class BadgeEndorsementInfo {
  const BadgeEndorsementInfo({required this.count, required this.endorsedByCurrentUser});

  final int count;
  final bool endorsedByCurrentUser;
}

abstract class PlayerBadgeEndorsementRepository {
  Future<BadgeEndorsementInfo> getEndorsementInfo({
    required String ownerUserId,
    required String badgeId,
    String? currentUserId,
  });

  Future<Result<Unit>> endorseBadge({
    required String ownerUserId,
    required String badgeId,
    required String badgeLocalizedName,
    required String endorserUserId,
    required String badgeCategory,
  });
}
