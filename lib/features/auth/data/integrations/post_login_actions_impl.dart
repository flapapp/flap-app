import '../../domain/contracts/post_login_actions.dart';
import '../../domain/entities/auth_user.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../notifications/data/services/notification_service.dart';

/// Data-layer implementation of post-login side effects.
class PostLoginActionsImpl implements PostLoginActions {
  PostLoginActionsImpl();

  @override
  Future<void> onEmailPasswordSignInSuccess(AuthUser user) async {
    try {
      await sl<AppSettingsCubit>().load(forceRefresh: true);
    } catch (_) {}
    try {
      await sl<NotificationService>().syncCurrentUserToken();
    } catch (_) {
      // Best-effort; session is already valid.
    }
  }
}
