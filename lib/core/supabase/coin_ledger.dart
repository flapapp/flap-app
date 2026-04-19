import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_lookups.dart';

Future<void> insertCoinTransaction(
  SupabaseClient client,
  String userId,
  String typeCode,
  int amount,
  String label,
) async {
  final tid = await SupabaseLookups.transactionTypeId(client, typeCode, label);
  await client.from('coin_transactions').insert(<String, dynamic>{
    'user_id': userId,
    'transaction_type_id': tid,
    'amount': amount,
    'description': label,
  });
}

Future<int> coinBalance(SupabaseClient client, String userId) async {
  final rows =
      await client.from('coin_transactions').select('amount').eq('user_id', userId);
  var sum = 0;
  for (final r in rows as List<dynamic>) {
    final m = r as Map<String, dynamic>;
    sum += (m['amount'] as num?)?.toInt() ?? 0;
  }
  return sum;
}
