import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/app_locale_access.dart';

import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
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
          tr('il_472d788d72'),
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
          tr('il_b512d97e7c');

      await _firestore.collection('notifications').add({
        'userId': ownerUserId,
        'type': 'badgeEndorsed',
        'title': tr('il_cd519087d2'),
        'message': bilingual(
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
            tr('il_f7964d75ff'),
          ),
        );
      }
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
