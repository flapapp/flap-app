import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flap_app/router/app_router.dart';

/// True when there is no signed-in user, or Firebase is not available (e.g. tests).
bool _isGuest() {
  try {
    return FirebaseAuth.instance.currentUser == null;
  } catch (_) {
    return true;
  }
}

/// Allows navigation only when there is **no** Firebase user session (guest flow).
/// Redirects authenticated users to the main hub [ModeSelectionRoute].
final class GuestGuard extends AutoRouteGuard {
  GuestGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (_isGuest()) {
      resolver.next();
      return;
    }
    resolver.next(false);
    router.replaceAll([const ModeSelectionRoute()]);
  }
}
