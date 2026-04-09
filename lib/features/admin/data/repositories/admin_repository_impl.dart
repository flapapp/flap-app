import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_data_source.dart';

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl(this._dataSource);

  final AdminRemoteDataSource _dataSource;

  @override
  Future<void> deleteAllChallengesAndSubmissions() =>
      _dataSource.deleteAllChallengesAndSubmissions();
}
