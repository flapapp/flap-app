import 'package:supabase_flutter/supabase_flutter.dart';

import 'subscription_remote_data_source.dart';

class SupabaseSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  Map<String, dynamic> _freeTierPatch(DateTime now) {
    final far = now.add(const Duration(days: 365 * 10));
    final patch = <String, dynamic>{
      'subscription': 'free',
      'subscription_status': 'active',
      'subscription_expiry': far.toUtc().toIso8601String(),
      'subscription_active': true,
      'subscription_auto_renew': false,
      'subscription_trial_end': null,
      'subscription_started_at': now.toUtc().toIso8601String(),
      'subscription_price': 0,
      'max_challenges_per_month': 1,
      'updated_at': now.toUtc().toIso8601String(),
    };
    return patch;
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileSubscriptionRow(String userId) async {
    var row = await _client
        .from('user_profiles')
        .select(SubscriptionRemoteDataSource.kSelectSubscriptionFields)
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    final subRaw = row['subscription'];
    final needsFree = subRaw == null ||
        (subRaw is String && subRaw.trim().isEmpty);

    if (needsFree) {
      final now = DateTime.now();
      await _client.from('user_profiles').update(_freeTierPatch(now)).eq('id', userId);
      row = await _client
          .from('user_profiles')
          .select(SubscriptionRemoteDataSource.kSelectSubscriptionFields)
          .eq('id', userId)
          .maybeSingle();
    }

    return row;
  }

  @override
  Stream<Map<String, dynamic>> watchProfileSubscriptionRow(String userId) {
    return _client
        .from('user_profiles')
        .stream(primaryKey: const ['id'])
        .eq('id', userId)
        .asyncMap((raw) async {
          if (raw.isEmpty) return <String, dynamic>{};
          final first = Map<String, dynamic>.from(raw.first as Map);
          final subRaw = first['subscription'];
          final needsFree = subRaw == null ||
              (subRaw is String && subRaw.trim().isEmpty);
          if (needsFree) {
            await _client
                .from('user_profiles')
                .update(_freeTierPatch(DateTime.now()))
                .eq('id', userId);
            final refreshed = await _client
                .from('user_profiles')
                .select(SubscriptionRemoteDataSource.kSelectSubscriptionFields)
                .eq('id', userId)
                .maybeSingle();
            return refreshed ?? first;
          }
          return first;
        });
  }

  @override
  Future<void> updateProfileSubscription(
    String userId,
    Map<String, dynamic> patch,
  ) async {
    final map = Map<String, dynamic>.from(patch);
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _client.from('user_profiles').update(map).eq('id', userId);
  }

  @override
  Future<void> creditCoinsForSubscriptionBonus({
    required int amount,
    required String description,
  }) async {
    await _client.rpc<void>(
      'subscription_credit_coins',
      params: <String, dynamic>{
        'p_amount': amount,
        'p_description': description,
      },
    );
  }
}
