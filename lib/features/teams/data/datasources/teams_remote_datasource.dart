import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore access for `teams` and `teamStats` collections (data layer).
abstract class TeamsRemoteDataSource {
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTeamDocument(String teamId);

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeamsOrderedByWins();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTeamStatsCollection();
}
