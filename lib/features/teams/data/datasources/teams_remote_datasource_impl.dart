import 'package:cloud_firestore/cloud_firestore.dart';

import 'teams_remote_datasource.dart';

class TeamsRemoteDataSourceImpl implements TeamsRemoteDataSource {
  TeamsRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTeamDocument(String teamId) {
    return _firestore.collection('teams').doc(teamId).snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeamsOrderedByWins() {
    return _firestore
        .collection('teams')
        .orderBy('wins', descending: true)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeamStatsCollection() {
    return _firestore.collection('teamStats').snapshots();
  }
}
