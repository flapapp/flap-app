import 'package:cloud_firestore/cloud_firestore.dart';

import 'player_videos_remote_datasource.dart';

class PlayerVideosRemoteDataSourceImpl implements PlayerVideosRemoteDataSource {
  PlayerVideosRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<Map<String, dynamic>>> listByUserId(String userId, int limit) async {
    final videosQuery = await _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .limit(limit)
        .get();

    final list = videosQuery.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    list.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  @override
  Future<List<String>> listVideoIdsForUser(String userId, int limit) async {
    final qs = await _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .limit(limit)
        .get();
    return qs.docs.map((d) => d.id).toList();
  }
}
