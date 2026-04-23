import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/register_request.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Result<AuthUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return const Result.failure(
          Failure.unexpected('missing-user-after-sign-in'),
        );
      }
      return Result.success(AuthUser(uid: uid));
    } on AuthException catch (e) {
      return Result.failure(
        Failure.auth(code: e.message, message: e.message),
      );
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }

  @override
  Future<Result<AuthUser>> registerNewUser(RegisterRequest r) async {
    try {
      final res = await _client.auth.signUp(
        email: r.email.trim(),
        password: r.password.trim(),
      );
      final user = res.user;
      if (user == null) {
        return const Result.failure(
          Failure.unexpected('missing-user-after-register'),
        );
      }
      final uid = user.id;

      // User bootstrap (profile/settings/signup bonus) is handled server-side
      // by auth.users trigger to avoid client-side RLS race conditions.

      return Result.success(AuthUser(uid: uid));
    } on AuthException catch (e) {
      return Result.failure(
        Failure.auth(code: e.message, message: e.message),
      );
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
