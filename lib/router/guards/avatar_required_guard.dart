import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flap_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:flap_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:flap_app/router/app_router.dart';

bool _hasCompletedNameProfile(Map<String, dynamic> doc) {
  final firstName = (doc['firstName'] ?? '').toString().trim();
  final lastName = (doc['lastName'] ?? '').toString().trim();
  return firstName.isNotEmpty && lastName.isNotEmpty;
}

/// After [AuthGuard], blocks app routes until profile data is complete.
/// Order: name details first, then avatar.
final class AvatarRequiredGuard extends AutoRouteGuard {
  AvatarRequiredGuard(this._sessionRepository, this._profileRepository);

  final AuthSessionRepository _sessionRepository;
  final ProfileRepository _profileRepository;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final uid = _sessionRepository.peekCurrentUser?.uid;
    if (uid == null) {
      resolver.next(false);
      router.replaceAll([const LoginRoute()]);
      return;
    }
    if (resolver.routeName == AvatarRequiredRoute.name ||
        resolver.routeName == ProfileCreationRoute.name) {
      resolver.next();
      return;
    }
    unawaited(_evaluate(resolver, router, uid));
  }

  Future<void> _evaluate(
    NavigationResolver resolver,
    StackRouter router,
    String uid,
  ) async {
    try {
      final profile = await _profileRepository.fetchUserProfile(uid);
      final hasNames =
          profile != null && _hasCompletedNameProfile(profile.document);
      final url = profile?.avatarUrl;
      final hasAvatar = url != null && url.trim().isNotEmpty;
      if (resolver.isResolved) return;
      if (!hasNames) {
        resolver.next(false);
        await router.replace(ProfileCreationRoute(isEditing: false));
      } else if (hasAvatar) {
        resolver.next();
      } else {
        resolver.next(false);
        await router.replace(const AvatarRequiredRoute());
      }
    } catch (_) {
      if (!resolver.isResolved) {
        resolver.next();
      }
    }
  }
}
