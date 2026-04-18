import 'package:cloud_firestore/cloud_firestore.dart';

abstract class MatchesReadRemoteDataSource {
  Future<DocumentSnapshot<Map<String, dynamic>>> getMatch(String matchId);
}
