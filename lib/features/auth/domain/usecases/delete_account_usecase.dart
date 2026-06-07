import 'dart:developer' as developer;

import '../../../../core/common/unit.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/no_params.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/account_repository.dart';
import '../repositories/auth_session_repository.dart';

/// Permanently deletes the current user's account and clears the local session.
///
/// The server RPC removes the auth user (database cascades drop all owned
/// rows); afterwards we sign out so the cached session/token is discarded and
/// the app can route back to the welcome flow.
class DeleteAccountUseCase implements UseCaseNoParams<Result<Unit>> {
  DeleteAccountUseCase(this._accountRepository, this._authSession);

  final AccountRepository _accountRepository;
  final AuthSessionRepository _authSession;

  @override
  Future<Result<Unit>> call([NoParams params = const NoParams()]) async {
    final uid = _authSession.peekCurrentUser?.uid;
    if (uid == null) {
      return const Result.failure(
        Failure.auth(code: 'unauthenticated', message: null),
      );
    }
    try {
      await _accountRepository.deleteAccount();
      // Best-effort local cleanup; the remote user is already gone.
      try {
        await _authSession.signOut();
      } catch (_) {}
      developer.log('Account deleted: $uid', name: 'DeleteAccountUseCase');
      return const Result.success(Unit.value);
    } catch (e, st) {
      developer.log(
        'Account deletion failed',
        name: 'DeleteAccountUseCase',
        error: e,
        stackTrace: st,
      );
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
