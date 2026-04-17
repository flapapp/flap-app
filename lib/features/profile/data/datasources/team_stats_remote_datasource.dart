import 'package:cloud_firestore/cloud_firestore.dart';

/// Live `teamStats/{teamId}` document (data layer).
abstract class TeamStatsRemoteDataSource {
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTeamStats(String teamId);
}
