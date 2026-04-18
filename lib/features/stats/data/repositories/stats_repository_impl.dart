import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/stats_repository.dart';

class StatsRepositoryImpl implements StatsRepository {
  StatsRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<UserStatsSnapshot> loadDashboard(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final history = List<Map<String, dynamic>>.from(data['ratingHistory'] ?? []);
    final now = DateTime.now();

    final history7 = history.where((h) {
      final ts = h['timestamp'];
      final dt = ts is Timestamp ? ts.toDate() : null;
      return dt != null && dt.isAfter(now.subtract(const Duration(days: 7)));
    }).toList()
      ..sort((a, b) {
        final at = a['timestamp'];
        final bt = b['timestamp'];
        if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
        return 0;
      });

    final history30 = history.where((h) {
      final ts = h['timestamp'];
      final dt = ts is Timestamp ? ts.toDate() : null;
      return dt != null && dt.isAfter(now.subtract(const Duration(days: 30)));
    }).toList()
      ..sort((a, b) {
        final at = a['timestamp'];
        final bt = b['timestamp'];
        if (at is Timestamp && bt is Timestamp) return at.compareTo(bt);
        return 0;
      });

    final counters = <String, num>{
      'matchesPlayed': (data['matchesPlayed'] ?? 0) as num,
      'matchesWon': (data['wins'] ?? 0) as num,
      'videosUploaded': (data['videosUploaded'] ?? 0) as num,
    };

    final vidsSnap = await _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .limit(50)
        .get();
    final vids = vidsSnap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data());
      m['id'] = d.id;
      return m;
    }).toList();
    vids.sort((a, b) => ((b['views'] ?? 0) as int).compareTo((a['views'] ?? 0) as int));
    final topVideos = vids.take(5).toList();

    return UserStatsSnapshot(
      ratingHistory7d: history7,
      ratingHistory30d: history30,
      topVideos: topVideos,
      counters: counters,
    );
  }
}
