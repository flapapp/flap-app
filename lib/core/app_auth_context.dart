import '../features/auth/domain/entities/app_user.dart';
import '../features/auth/domain/repositories/auth_repository.dart';

/// Global access to the active [AuthRepository] for services that are not yet
/// refactored behind use-cases. Set once from [main] after the repository is created.
class AppAuthContext {
  AppAuthContext._();

  static AuthRepository? repository;

  static AppUser? get currentUser => repository?.currentUser;

  static String? get userId => currentUser?.id;
}
