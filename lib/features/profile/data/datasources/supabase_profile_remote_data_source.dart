import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_remote_data_source.dart';

class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;
  static const _writeTimeout = Duration(seconds: 15);
  static const _fallbackUsernamePrefix = 'user_';

  @override
  Stream<Map<String, dynamic>> watchProfileRow(String userId) {
    return _client
        .from('user_profiles')
        .stream(primaryKey: const ['id'])
        .eq('id', userId)
        .map((rows) {
          if (rows.isEmpty) return <String, dynamic>{};
          return Map<String, dynamic>.from(rows.first as Map);
        });
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileRow(String userId) async {
    return _client
        .from('user_profiles')
        .select(ProfileRemoteDataSource.kSelectFull)
        .eq('id', userId)
        .maybeSingle();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchWalletTransactions(String userId) {
    return _client
        .from('wallet_transactions')
        .stream(primaryKey: const ['id'])
        .eq('user_id', userId)
        .map((raw) {
          final rows = (raw as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
            ..sort((a, b) {
              final as = a['created_at']?.toString();
              final bs = b['created_at']?.toString();
              final at = DateTime.tryParse(as ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bt = DateTime.tryParse(bs ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            });
          return rows;
        });
  }

  @override
  Future<void> mergeSettings(
    String userId,
    Map<String, dynamic> partial,
  ) async {
    final row = await _client
        .from('user_profiles')
        .select('settings')
        .eq('id', userId)
        .maybeSingle();
    final cur = Map<String, dynamic>.from(
      (row?['settings'] is Map)
          ? row!['settings'] as Map<dynamic, dynamic>
          : const {},
    );
    partial.forEach((key, value) {
      cur[key] = value;
    });
    await _client.from('user_profiles').update({
      'settings': cur,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  @override
  Future<void> completeProfile({
    required String userId,
    required Map<String, dynamic> payload,
  }) async {
    final rows = await _client
        .from('user_profiles')
        .update(payload)
        .eq('id', userId)
        .select('id')
        .timeout(_writeTimeout);
    if ((rows as List).isNotEmpty) return;

    // Fallback: for environments where the auth->profile trigger did not create
    // the row, insert a minimal row and apply profile completion payload.
    final currentUser = _client.auth.currentUser;
    final insertPayload = <String, dynamic>{
      'id': userId,
      'username': _fallbackUsername(userId),
      'email': currentUser?.email,
      ...payload,
    };
    final inserted = await _client
        .from('user_profiles')
        .upsert(insertPayload, onConflict: 'id')
        .select('id')
        .timeout(_writeTimeout);
    if ((inserted as List).isEmpty) {
      throw StateError(
        'Profile row not found or not writable for user $userId.',
      );
    }
  }

  @override
  Future<void> setAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    final rows = await _client
        .from('user_profiles')
        .update({
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select('id')
        .timeout(_writeTimeout);
    if ((rows as List).isEmpty) {
      throw StateError(
        'Could not persist avatar_url; profile row missing or not writable for user $userId.',
      );
    }
  }

  static String _fallbackUsername(String userId) {
    final normalized = userId.replaceAll('-', '').toLowerCase();
    return '$_fallbackUsernamePrefix$normalized';
  }
}
