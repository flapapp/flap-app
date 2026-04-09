import 'package:auto_route/auto_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_auth_context.dart';
import 'app_router.dart';

/// Allows navigation only when user is authenticated.
class AuthGuard extends AutoRouteGuard {
  const AuthGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final isAuthenticated = AppAuthContext.repository?.currentUser != null;
    if (isAuthenticated) {
      resolver.next(true);
      return;
    }

    router.replaceAll([const WelcomeRoute()]);
    resolver.next(false);
  }
}

/// Allows navigation only for unauthenticated users.
class GuestOnlyGuard extends AutoRouteGuard {
  const GuestOnlyGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final isAuthenticated = AppAuthContext.repository?.currentUser != null;
    if (!isAuthenticated) {
      resolver.next(true);
      return;
    }

    router.replaceAll([const ModeSelectionRoute()]);
    resolver.next(false);
  }
}

/// Shows intro only on very first app launch.
class FirstLaunchGuard extends AutoRouteGuard {
  const FirstLaunchGuard();

  static const _kHasLaunchedBefore = 'has_launched_before';

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) async {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunchedBefore = prefs.getBool(_kHasLaunchedBefore) ?? false;

    if (!hasLaunchedBefore) {
      await prefs.setBool(_kHasLaunchedBefore, true);
      resolver.next(true);
      return;
    }

    final isAuthenticated = AppAuthContext.repository?.currentUser != null;
    if (isAuthenticated) {
      router.replaceAll([const ModeSelectionRoute()]);
    } else {
      router.replaceAll([const WelcomeRoute()]);
    }
    resolver.next(false);
  }
}
