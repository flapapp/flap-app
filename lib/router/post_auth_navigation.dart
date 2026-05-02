import 'package:auto_route/auto_route.dart';

import '../core/di/injection.dart';
import '../features/auth/domain/repositories/auth_session_repository.dart';
import '../features/profile/domain/entities/user_profile.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import 'app_router.dart';
import 'onboarding_route_rules.dart';

/// Chooses profile onboarding vs mode selection from an already-loaded profile (or null if missing).
PageRouteInfo<void> postAuthRouteForProfile(UserProfile? profile) {
  final hasNames =
      profile != null && onboardingHasCompletedNames(profile.document);
  if (!hasNames) {
    return ProfileCreationRoute(isEditing: false);
  }
  final url = profile.avatarUrl;
  final hasAvatar = url != null && url.trim().isNotEmpty;
  if (hasAvatar) {
    return const ModeSelectionRoute();
  }
  return const AvatarRequiredRoute();
}

/// After sign-in or cold start with a session, choose mandatory onboarding step.
Future<PageRouteInfo<void>> resolvePostAuthInitialRoute() async {
  final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
  if (uid == null) {
    return const LoginRoute();
  }
  final profile = await sl<ProfileRepository>().fetchUserProfile(uid);
  return postAuthRouteForProfile(profile);
}
