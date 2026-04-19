import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/error/failure.dart';
import '../../../../core/supabase/supabase_app_storage.dart';
import '../../../../core/error/result.dart';
import '../../../../core/supabase/coin_ledger.dart';
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
        Failure.auth(code: e.message ?? 'auth', message: e.message),
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

      String? avatarUrl;
      final bytes = r.avatarBytes;
      if (bytes != null && bytes.isNotEmpty) {
        try {
          avatarUrl = await SupabaseAppStorage.uploadPublicBytes(
            _client,
            bucket: SupabaseAppStorage.avatars,
            path: '$uid/avatar.jpg',
            bytes: Uint8List.fromList(bytes),
            contentType: 'image/jpeg',
            upsert: true,
          );
        } catch (_) {}
      }

      final fullName = '${r.name.trim()} ${r.surname.trim()}'.trim();
      final dob = DateTime(DateTime.now().year - r.age, 1, 1);

      await _client.from('profiles').insert(<String, dynamic>{
        'id': uid,
        'email': r.email.trim(),
        'display_name': fullName.isNotEmpty ? fullName : r.email.trim(),
        'first_name': r.name.trim(),
        'last_name': r.surname.trim(),
        'city': r.city.trim(),
        'position': r.position,
        'avatar_url': avatarUrl,
        'dat_of_birth': dob.toIso8601String().split('T').first,
      });

      await _client.from('user_settings').insert(<String, dynamic>{
        'user_id': uid,
        'locale': 'en',
        'notifications_enabled': true,
        'autoplay_videos': true,
      });

      await insertCoinTransaction(
        _client,
        uid,
        'signup_bonus',
        160,
        'Welcome coins',
      );

      return Result.success(AuthUser(uid: uid));
    } on AuthException catch (e) {
      return Result.failure(
        Failure.auth(code: e.message ?? 'auth', message: e.message),
      );
    } catch (e) {
      return Result.failure(Failure.unexpected(e.toString()));
    }
  }
}
