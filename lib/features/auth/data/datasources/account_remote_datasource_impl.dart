import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_remote_datasource.dart';

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  AccountRemoteDataSourceImpl();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> deleteAccount() async {
    await _client.rpc('delete_account');
  }
}
