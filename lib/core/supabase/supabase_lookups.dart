import 'package:supabase_flutter/supabase_flutter.dart';

/// Ensures lookup rows exist for FK references used by the client.
class SupabaseLookups {
  SupabaseLookups._();

  static Future<String> transactionTypeId(
    SupabaseClient client,
    String code,
    String label,
  ) async {
    final existing = await client
        .from('transaction_types')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }
    final inserted = await client
        .from('transaction_types')
        .insert(<String, dynamic>{'code': code, 'label': label})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  static Future<String> notificationTypeId(
    SupabaseClient client,
    String code,
    String label,
  ) async {
    final existing = await client
        .from('notification_types')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }
    final inserted = await client
        .from('notification_types')
        .insert(<String, dynamic>{'code': code, 'label': label})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  static Future<String> subscriptionPlanId(
    SupabaseClient client,
    String code,
    String name, {
    int priceMonthly = 0,
  }) async {
    final existing = await client
        .from('subscription_plans')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    if (existing != null) {
      return existing['id'] as String;
    }
    final inserted = await client
        .from('subscription_plans')
        .insert(<String, dynamic>{
          'code': code,
          'name': name,
          'price_monthly': priceMonthly,
          'is_active': true,
        })
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  static Future<String?> challengeTypeIdByCode(
    SupabaseClient client,
    String code,
  ) async {
    final row = await client
        .from('challenge_types')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    return row?['id'] as String?;
  }

  static Future<String> ensureChallengeType(
    SupabaseClient client,
    String code,
    String label,
  ) async {
    final existing = await challengeTypeIdByCode(client, code);
    if (existing != null) {
      return existing;
    }
    final inserted = await client
        .from('challenge_types')
        .insert(<String, dynamic>{'code': code, 'label': label})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  static Future<String?> challengeAudienceIdByCode(
    SupabaseClient client,
    String code,
  ) async {
    final row = await client
        .from('challenge_audiences')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    return row?['id'] as String?;
  }

  static Future<String> ensureChallengeAudience(
    SupabaseClient client,
    String code,
    String label,
  ) async {
    final existing = await challengeAudienceIdByCode(client, code);
    if (existing != null) {
      return existing;
    }
    final inserted = await client
        .from('challenge_audiences')
        .insert(<String, dynamic>{'code': code, 'label': label})
        .select('id')
        .single();
    return inserted['id'] as String;
  }

  static Future<String?> videoCategoryIdByCode(
    SupabaseClient client,
    String code,
  ) async {
    final row = await client
        .from('video_categories')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    return row?['id'] as String?;
  }

  static Future<String?> videoDifficultyIdByCode(
    SupabaseClient client,
    String code,
  ) async {
    final row = await client
        .from('video_difficulties')
        .select('id')
        .eq('code', code)
        .maybeSingle();
    return row?['id'] as String?;
  }
}
