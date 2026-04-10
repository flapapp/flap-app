import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_remote_data_source.dart';

class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Stream<Map<String, dynamic>> watchProfileRow(String userId) {
    return _client
        .from('profiles')
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
        .from('profiles')
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
        .from('profiles')
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
    await _client.from('profiles').update({
      'settings': cur,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
