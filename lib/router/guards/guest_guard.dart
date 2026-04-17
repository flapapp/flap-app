import 'package:auto_route/auto_route.dart';
import 'package:flap_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:flap_app/router/app_router.dart';

/// Allows navigation only when there is no authenticated session (guest flow).
/// Redirects signed-in users to the main hub [ModeSelectionRoute].
final class GuestGuard extends AutoRouteGuard {
  GuestGuard(this._sessionRepository);

  final AuthSessionRepository _sessionRepository;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (_sessionRepository.peekCurrentUser == null) {
      resolver.next();
      return;
    }
    resolver.next(false);
    router.replaceAll([const ModeSelectionRoute()]);
  }
}
