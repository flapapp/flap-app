import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/badge_failure.dart';
import 'badge_remote_data_source.dart';

class SupabaseBadgeRemoteDataSource implements BadgeRemoteDataSource {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> upsertDefaultBadges(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    const chunk = 25;
    for (var i = 0; i < rows.length; i += chunk) {
      final end = i + chunk > rows.length ? rows.length : i + chunk;
      await _client.from('badges').upsert(
            rows.sublist(i, end),
            onConflict: 'id',
          );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableBadges() async {
    final rows = await _client
        .from('badges')
        .select()
        .eq('is_available', true)
        .order('price');
    return List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBadgesByCategory(String category) async {
    final rows = await _client
        .from('badges')
        .select()
        .eq('category', category)
        .eq('is_available', true)
        .order('price');
    return List<Map<String, dynamic>>.from(
      (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  @override
  Future<List<String>> fetchUserBadgeIds(String userId) async {
    final rows = await _client
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);
    return (rows as List)
        .map((e) => (e as Map)['badge_id'] as String)
        .toList();
  }

  @override
  Future<int> fetchUserCoins(String userId) async {
    final row = await _client
        .from('user_profiles')
        .select('coins')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return 0;
    return (row['coins'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> rpcPurchaseBadge(String badgeId) async {
    try {
      await _client.rpc<void>(
        'purchase_badge',
        params: <String, dynamic>{'p_badge_id': badgeId},
      );
    } on PostgrestException catch (e) {
      throw _mapPurchaseException(e);
    }
  }

  @override
  Future<bool> rpcAwardBadge({
    required String userId,
    required String badgeId,
    required String reason,
  }) async {
    try {
      final res = await _client.rpc<dynamic>(
        'award_badge',
        params: <String, dynamic>{
          'p_user_id': userId,
          'p_badge_id': badgeId,
          'p_reason': reason,
        },
      );
      if (res is bool) return res;
      return true;
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('forbidden')) {
        throw const BadgeFailure(code: 'forbidden', message: 'Forbidden.');
      }
      throw BadgeFailure(code: e.code ?? 'award-error', message: e.message);
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchBadgeRow(String badgeId) async {
    return _client.from('badges').select().eq('id', badgeId).maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> fetchProfileActivityRow(String userId) async {
    return _client
        .from('user_profiles')
        .select('friends_count, matches, total_matches, video_rating')
        .eq('id', userId)
        .maybeSingle();
  }

  BadgeFailure _mapPurchaseException(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase();
    if (code == 'p0001' || msg.contains('not_authenticated')) {
      return const BadgeFailure(
        code: 'not-authenticated',
        message: 'User not signed in.',
      );
    }
    if (msg.contains('badge_not_found')) {
      return const BadgeFailure(code: 'badge-not-found', message: 'Badge not found.');
    }
    if (msg.contains('badge_unavailable')) {
      return const BadgeFailure(
        code: 'badge-unavailable',
        message: 'Badge unavailable.',
      );
    }
    if (msg.contains('already_owned')) {
      return const BadgeFailure(code: 'already-owned', message: 'Already owned.');
    }
    if (msg.contains('profile_not_found')) {
      return const BadgeFailure(code: 'profile-not-found', message: 'Profile not found.');
    }
    if (msg.contains('insufficient_coins')) {
      return const BadgeFailure(
        code: 'insufficient-coins',
        message: 'Not enough coins.',
      );
    }
    return BadgeFailure(code: e.code ?? 'purchase-error', message: e.message);
  }
}
