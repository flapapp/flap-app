import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flap_app/router/app_router.dart';

bool _hasSignedInUser() {
  try {
    return FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    return false;
  }
}

/// Allows navigation only when a Firebase user session exists.
/// Redirects unauthenticated users to [LoginRoute] and clears invalid navigation.
final class AuthGuard extends AutoRouteGuard {
  AuthGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (_hasSignedInUser()) {
      resolver.next();
      return;
    }
    resolver.next(false);
    router.replaceAll([const LoginRoute()]);
  }
}
