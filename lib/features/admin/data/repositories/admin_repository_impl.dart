import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> deleteAllChallenges() async {
    final submissions = await _firestore.collection('submissions').get();
    final submissionBatch = _firestore.batch();
    for (final doc in submissions.docs) {
      submissionBatch.delete(doc.reference);
    }
    await submissionBatch.commit();

    final challenges = await _firestore.collection('challenges').get();
    final challengeBatch = _firestore.batch();
    for (final doc in challenges.docs) {
      challengeBatch.delete(doc.reference);
    }
    await challengeBatch.commit();
  }
}
