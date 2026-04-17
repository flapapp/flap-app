import 'package:cloud_firestore/cloud_firestore.dart';

import 'team_stats_remote_datasource.dart';

class TeamStatsRemoteDataSourceImpl implements TeamStatsRemoteDataSource {
  TeamStatsRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTeamStats(String teamId) {
    return _firestore.collection('teamStats').doc(teamId).snapshots();
  }
}
