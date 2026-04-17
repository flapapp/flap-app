import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/player_profile_dashboard_data.dart';
import '../repositories/player_profile_dashboard_repository.dart';

class LoadPlayerProfileDashboardParams {
  const LoadPlayerProfileDashboardParams({required this.playerId});

  final String playerId;
}

class LoadPlayerProfileDashboardUseCase
    implements UseCase<Result<PlayerProfileDashboardData>, LoadPlayerProfileDashboardParams> {
  LoadPlayerProfileDashboardUseCase(this._repository);

  final PlayerProfileDashboardRepository _repository;

  @override
  Future<Result<PlayerProfileDashboardData>> call(
    LoadPlayerProfileDashboardParams params,
  ) async {
    try {
      final data = await _repository.loadDashboard(params.playerId);
      return Result.success(data);
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
