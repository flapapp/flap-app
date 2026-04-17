import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/player_challenge_invite_repository.dart';

class PlayerChallengeInviteRepositoryImpl implements PlayerChallengeInviteRepository {
  PlayerChallengeInviteRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<Map<String, dynamic>>> listInvitableChallenges({
    required String creatorUserId,
    required String targetPlayerId,
  }) async {
    final snap = await _firestore
        .collection('challenges')
        .where('creatorId', isEqualTo: creatorUserId)
        .limit(50)
        .get();

    return snap.docs
        .map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        })
        .where((c) {
          final participants = List<String>.from(c['participants'] ?? []);
          return !participants.contains(targetPlayerId);
        })
        .toList();
  }
}
