import 'package:auto_route/auto_route.dart';
import 'package:flap_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:flap_app/router/app_router.dart';

/// Allows navigation only when an authenticated session exists (domain-driven).
/// Redirects unauthenticated users to [LoginRoute] and clears invalid navigation.
final class AuthGuard extends AutoRouteGuard {
  AuthGuard(this._sessionRepository);

  final AuthSessionRepository _sessionRepository;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (_sessionRepository.peekCurrentUser != null) {
      resolver.next();
      return;
    }
    resolver.next(false);
    router.replaceAll([const LoginRoute()]);
  }
}
