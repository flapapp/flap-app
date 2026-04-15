import 'package:auto_route/auto_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_auth_context.dart';
import '../app_user_profile_context.dart';
import 'app_router.dart';

/// After auth: requires `user_profiles.profile_complete` before main app routes.
/// [ProfileCreationRoute] is always allowed for signed-in users.
class ProfileCompletionGuard extends AutoRouteGuard {
  const ProfileCompletionGuard();

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) async {
    final targetName = resolver.route.name;
    if (targetName == ProfileCreationRoute.name) {
      resolver.next(true);
      return;
    }

    final uid = AppAuthContext.userId;
    if (uid == null) {
      resolver.next(true);
      return;
    }

    final repo = AppUserProfileContext.repository;
    if (repo == null) {
      resolver.next(true);
      return;
    }

    try {
      final complete = await repo.isProfileComplete(uid);
      if (complete) {
        resolver.next(true);
      } else {
        await router.replaceAll([ProfileCreationRoute()]);
        resolver.next(false);
      }
    } catch (_) {
      // Fail closed so users still complete profile if profile-read errors occur.
      await router.replaceAll([ProfileCreationRoute()]);
      resolver.next(false);
    }
  }
}

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

    router.replaceAll([const MainShellRoute()]);
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
      router.replaceAll([const MainShellRoute()]);
    } else {
      router.replaceAll([const WelcomeRoute()]);
    }
    resolver.next(false);
  }
}
