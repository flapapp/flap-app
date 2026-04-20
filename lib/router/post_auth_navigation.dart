import 'package:auto_route/auto_route.dart';

import '../core/di/injection.dart';
import '../features/auth/domain/repositories/auth_session_repository.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import 'app_router.dart';

/// After sign-in or cold start with a session, choose hub vs mandatory avatar upload.
Future<PageRouteInfo<void>> resolvePostAuthInitialRoute() async {
  final uid = sl<AuthSessionRepository>().peekCurrentUser?.uid;
  if (uid == null) {
    return const LoginRoute();
  }
  final profile = await sl<ProfileRepository>().fetchUserProfile(uid);
  final url = profile?.avatarUrl;
  final hasAvatar = url != null && url.trim().isNotEmpty;
  if (hasAvatar) {
    return const ModeSelectionRoute();
  }
  return const AvatarRequiredRoute();
}
