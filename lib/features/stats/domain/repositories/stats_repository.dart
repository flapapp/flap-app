/// Aggregated rating history, counters, and top videos for the stats dashboard.
class UserStatsSnapshot {
  const UserStatsSnapshot({
    required this.ratingHistory7d,
    required this.ratingHistory30d,
    required this.topVideos,
    required this.counters,
  });

  final List<Map<String, dynamic>> ratingHistory7d;
  final List<Map<String, dynamic>> ratingHistory30d;
  final List<Map<String, dynamic>> topVideos;
  final Map<String, num> counters;
}

abstract class StatsRepository {
  Future<UserStatsSnapshot> loadDashboard(String userId);
}
