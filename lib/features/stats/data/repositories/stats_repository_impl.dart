import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_date.dart';
import '../../domain/repositories/stats_repository.dart';

class StatsRepositoryImpl implements StatsRepository {
  StatsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<UserStatsSnapshot> loadDashboard(String userId) async {
    final snapRows = await _client
        .from('user_rating_snapshots')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(200);

    final history = <Map<String, dynamic>>[];
    for (final raw in snapRows as List<dynamic>) {
      final m = raw as Map<String, dynamic>;
      history.add(<String, dynamic>{
        'rating': m['rating_value'],
        'timestamp': m['created_at'],
        'scope': m['rating_scope'],
      });
    }

    final now = DateTime.now();
    List<Map<String, dynamic>> filterDays(int days) {
      return history.where((h) {
        final dt = asDateTimeOrNull(h['timestamp']);
        return dt != null && dt.isAfter(now.subtract(Duration(days: days)));
      }).toList()
        ..sort((a, b) {
          final at = asDateTimeOrNull(a['timestamp']);
          final bt = asDateTimeOrNull(b['timestamp']);
          if (at == null || bt == null) {
            return 0;
          }
          return at.compareTo(bt);
        });
    }

    final history7 = filterDays(7);
    final history30 = filterDays(30);

    final matchRows = await _client
        .from('match_participants')
        .select('match_id')
        .eq('user_id', userId)
        .eq('status', 'accepted');
    final matchesPlayed = (matchRows as List<dynamic>).length;

    final vidRows = await _client
        .from('videos')
        .select('id')
        .eq('user_id', userId);
    final videosUploaded = (vidRows as List<dynamic>).length;

    final vidsDetailed = await _client
        .from('videos')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    final vids = (vidsDetailed as List<dynamic>).map((r) {
      final m = Map<String, dynamic>.from(r as Map<String, dynamic>);
      m['id'] = m['id']?.toString();
      m['userId'] = m['user_id'];
      m['views'] = 0;
      return m;
    }).toList();

    final counters = <String, num>{
      'matchesPlayed': matchesPlayed,
      'matchesWon': 0,
      'videosUploaded': videosUploaded,
    };

    return UserStatsSnapshot(
      ratingHistory7d: history7,
      ratingHistory30d: history30,
      topVideos: vids.take(5).toList(),
      counters: counters,
    );
  }
}
