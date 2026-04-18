import 'package:cloud_firestore/cloud_firestore.dart';

import 'matches_read_remote_datasource.dart';

class MatchesReadRemoteDataSourceImpl implements MatchesReadRemoteDataSource {
  MatchesReadRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getMatch(String matchId) {
    return _firestore.collection('matches').doc(matchId).get();
  }
}
