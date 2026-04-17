import '../../domain/contracts/post_login_actions.dart';
import '../../domain/entities/auth_user.dart';
import '../../../../services/notification_service.dart';

/// Data-layer implementation of post-login side effects.
class PostLoginActionsImpl implements PostLoginActions {
  PostLoginActionsImpl();

  @override
  Future<void> onEmailPasswordSignInSuccess(AuthUser user) async {
    try {
      await NotificationService().syncCurrentUserToken();
    } catch (_) {
      // Best-effort; session is already valid.
    }
  }
}
