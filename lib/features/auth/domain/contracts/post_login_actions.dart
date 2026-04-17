import '../entities/auth_user.dart';

/// Application hook after a successful credential sign-in (domain contract).
/// Implemented in the data layer (e.g. push tokens, analytics).
abstract class PostLoginActions {
  Future<void> onEmailPasswordSignInSuccess(AuthUser user);
}
