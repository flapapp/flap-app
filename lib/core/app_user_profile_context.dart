import '../features/auth/domain/repositories/user_profile_repository.dart';

/// Global access for router guards and services without [BuildContext].
/// Set once from [main] after the repository is created.
class AppUserProfileContext {
  AppUserProfileContext._();

  static UserProfileRepository? repository;
}
