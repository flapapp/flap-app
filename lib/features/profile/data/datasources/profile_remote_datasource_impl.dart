import 'package:cloud_firestore/cloud_firestore.dart';

import 'profile_remote_datasource.dart';

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection('users').doc(userId);

  @override
  Stream<Map<String, dynamic>?> watchUserDocument(String userId) {
    return _userRef(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data();
    });
  }

  @override
  Future<Map<String, dynamic>?> getUserDocument(String userId) async {
    final snap = await _userRef(userId).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  @override
  Future<void> mergeUserSettings(
    String userId,
    Map<String, dynamic> settingsPatch,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final ref = _userRef(userId);
      final snap = await transaction.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final prev = data['settings'];
      final Map<String, dynamic> merged;
      if (prev is Map<String, dynamic>) {
        merged = Map<String, dynamic>.from(prev);
      } else if (prev is Map) {
        merged = Map<String, dynamic>.from(prev);
      } else {
        merged = <String, dynamic>{};
      }
      merged.addAll(settingsPatch);
      transaction.set(ref, <String, dynamic>{'settings': merged}, SetOptions(merge: true));
    });
  }

  @override
  Future<void> mergeUserDocument(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    await _userRef(userId).set(patch, SetOptions(merge: true));
  }

  @override
  Future<void> trySeedDemoCrossFriends(String userId) async {
    try {
      final existing = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: userId)
          .limit(4)
          .get();
      final friendIds = existing.docs.map((d) => d.id).toList();
      if (friendIds.isEmpty) return;
      final userRef = _userRef(userId);
      await userRef.set(
        {'friends': FieldValue.arrayUnion(friendIds)},
        SetOptions(merge: true),
      );
      for (final fid in friendIds) {
        await _userRef(fid).set(
          {'friends': FieldValue.arrayUnion([userId])},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  @override
  Future<Map<String, Map<String, dynamic>>> getUserDocumentsByIds(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    const chunkSize = 10;
    final out = <String, Map<String, dynamic>>{};
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.skip(i).take(chunkSize).toList();
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        out[doc.id] = doc.data();
      }
    }
    return out;
  }
}
