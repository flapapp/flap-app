import '../../domain/repositories/intro_settings_repository.dart';
import '../datasources/intro_local_datasource.dart';

class IntroSettingsRepositoryImpl implements IntroSettingsRepository {
  IntroSettingsRepositoryImpl(this._local);

  final IntroLocalDataSource _local;

  @override
  Future<bool> isIntroCompleted() => _local.getIntroCompleted();

  @override
  Future<void> markIntroCompleted() => _local.setIntroCompleted(true);
}
