import '../entities/auth_user.dart';

/// Resolves the current auth session for startup / guards (domain contract).
abstract class AuthSessionRepository {
  /// Waits for the auth provider to restore session where applicable, then returns user.
  Future<AuthUser?> resolveInitialSession();

  /// Synchronous read of the current session if the provider already has it (routing guards).
  AuthUser? get peekCurrentUser;
}
