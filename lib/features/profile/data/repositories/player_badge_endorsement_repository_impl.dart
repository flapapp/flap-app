import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../utils/i18n.dart';
import '../../domain/repositories/player_badge_endorsement_repository.dart';

class PlayerBadgeEndorsementRepositoryImpl
    implements PlayerBadgeEndorsementRepository {
  PlayerBadgeEndorsementRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<BadgeEndorsementInfo> getEndorsementInfo({
    required String ownerUserId,
    required String badgeId,
    String? currentUserId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(ownerUserId)
          .collection('badge_endorsements')
          .doc(badgeId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final endorsers = List<String>.from(data['endorsers'] ?? []);
        final endorsed =
            currentUserId != null && endorsers.contains(currentUserId);
        return BadgeEndorsementInfo(
          count: endorsers.length,
          endorsedByCurrentUser: endorsed,
        );
      }
      return const BadgeEndorsementInfo(count: 0, endorsedByCurrentUser: false);
    } catch (_) {
      return const BadgeEndorsementInfo(count: 0, endorsedByCurrentUser: false);
    }
  }

  @override
  Future<Result<Unit>> endorseBadge({
    required String ownerUserId,
    required String badgeId,
    required String badgeLocalizedName,
    required String endorserUserId,
  }) async {
    if (endorserUserId == ownerUserId) {
      return Result.failure(
        Failure.unexpected(
          I18n.inline(
            'Не можна підтверджувати власні бейджі',
            'You cannot endorse your own badges',
          ),
        ),
      );
    }

    final ref = _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('badge_endorsements')
        .doc(badgeId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        var endorsers = <String>[];
        if (snap.exists) {
          endorsers = List<String>.from(snap.data()?['endorsers'] ?? []);
        }
        if (endorsers.contains(endorserUserId)) {
          throw StateError('already-endorsed');
        }
        endorsers.add(endorserUserId);
        tx.set(
          ref,
          {
            'endorsers': endorsers,
            'lastEndorsedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      final currentUserDoc =
          await _firestore.collection('users').doc(endorserUserId).get();
      final currentName = currentUserDoc.data()?['displayName'] ??
          currentUserDoc.data()?['name'] ??
          I18n.inline('Користувач', 'User');

      await _firestore.collection('notifications').add({
        'userId': ownerUserId,
        'type': 'badgeEndorsed',
        'title': I18n.inline('Підтвердження бейджу', 'Badge endorsement'),
        'message': I18n.inline(
          '$currentName підтвердив ваш бейдж "$badgeLocalizedName"',
          '$currentName confirmed your badge "$badgeLocalizedName"',
        ),
        'data': {'badgeId': badgeId},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      return const Result.success(Unit.value);
    } catch (e) {
      if (e is StateError && e.message == 'already-endorsed') {
        return Result.failure(
          Failure.unexpected(
            I18n.inline(
              'Ви вже підтвердили цей бейдж',
              'You already endorsed this badge',
            ),
          ),
        );
      }
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
