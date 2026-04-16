import 'package:supabase_flutter/supabase_flutter.dart';

import 'wallet_remote_data_source.dart';

class SupabaseWalletRemoteDataSource implements WalletRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<Map<String, dynamic>?> fetchMyWallet() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('user_wallets')
        .select('id, user_id, balance, locked_balance, currency, total_earned, total_spent, status, updated_at')
        .eq('user_id', uid)
        .maybeSingle();
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMyTransactions({int limit = 50}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await _client
        .from('transactions')
        .select('id, type, amount, currency, status, description, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.cast<Map<String, dynamic>>();
  }
}
