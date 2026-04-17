import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_session_remote_datasource.dart';
import '../../features/auth/data/datasources/auth_session_remote_datasource_impl.dart';
import '../../features/auth/data/datasources/intro_local_datasource.dart';
import '../../features/auth/data/datasources/intro_local_datasource_impl.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/auth_session_repository_impl.dart';
import '../../features/auth/data/repositories/intro_settings_repository_impl.dart';
import '../../features/auth/data/integrations/post_login_actions_impl.dart';
import '../../features/auth/domain/contracts/post_login_actions.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/auth_session_repository.dart';
import '../../features/auth/domain/repositories/intro_settings_repository.dart';
import '../../features/auth/domain/usecases/check_intro_completed_usecase.dart';
import '../../features/auth/domain/usecases/mark_intro_completed_usecase.dart';
import '../../features/auth/domain/usecases/register_new_user_usecase.dart';
import '../../features/auth/domain/usecases/resolve_startup_navigation_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_with_email_usecase.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  sl
    ..registerLazySingleton<AuthSessionRemoteDataSource>(
      AuthSessionRemoteDataSourceImpl.new,
    )
    ..registerLazySingleton<IntroLocalDataSource>(
      IntroLocalDataSourceImpl.new,
    )
    ..registerLazySingleton<AuthSessionRepository>(
      () => AuthSessionRepositoryImpl(sl()),
    )
    ..registerLazySingleton<IntroSettingsRepository>(
      () => IntroSettingsRepositoryImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      AuthRepositoryImpl.new,
    )
    ..registerLazySingleton<PostLoginActions>(
      PostLoginActionsImpl.new,
    )
    ..registerLazySingleton(
      () => SignInWithEmailUseCase(sl()),
    )
    ..registerLazySingleton(
      () => RegisterNewUserUseCase(sl()),
    )
    ..registerLazySingleton(
      () => ResolveStartupNavigationUseCase(sl(), sl()),
    )
    ..registerLazySingleton(
      () => MarkIntroCompletedUseCase(sl()),
    )
    ..registerLazySingleton(
      () => CheckIntroCompletedUseCase(sl()),
    );
}
