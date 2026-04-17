import '../entities/player_profile_dashboard_data.dart';

abstract class PlayerProfileDashboardRepository {
  Future<PlayerProfileDashboardData> loadDashboard(String playerId);
}
