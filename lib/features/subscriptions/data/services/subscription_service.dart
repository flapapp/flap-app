import 'package:easy_localization/easy_localization.dart';
import 'package:flap_app/core/auth/app_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/subscription.dart';

/// Reads subscription state from Supabase. All *writes* to a premium
/// subscription happen server-side in the `paddle-webhook` edge function — the
/// client never grants itself premium. The only client-side mutation is a soft
/// cancel (turning off auto-renew); Paddle emits the authoritative state change
/// via the webhook afterwards.
class SubscriptionService {
  final SupabaseClient _client = Supabase.instance.client;

  /// The user's current subscription, or an in-memory free placeholder when
  /// they have no active premium row. Never writes a free row to the DB.
  Future<Subscription?> getUserSubscription(String userId) async {
    try {
      final row = await _activeSubscriptionRow(userId);
      if (row == null) return _freePlaceholder(userId);
      return _toSubscription(row);
    } catch (_) {
      // Fail closed to view-only rather than blocking the UI on a read error.
      return _freePlaceholder(userId);
    }
  }

  /// Whether the user currently has premium access (trialing or active).
  Future<bool> hasActiveSubscription([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return false;
    final subscription = await getUserSubscription(userId);
    return subscription?.isPremiumActive ?? false;
  }

  Future<SubscriptionType> getSubscriptionType([String? userId]) async {
    userId ??= AppAuth.currentUserId;
    if (userId == null) return SubscriptionType.free;
    final subscription = await getUserSubscription(userId);
    return subscription?.type ?? SubscriptionType.free;
  }

  /// Soft-cancels the active subscription by turning off auto-renew. The
  /// account keeps premium access until the end of the current period; Paddle
  /// sends `subscription.canceled`/`subscription.updated` which the webhook
  /// applies as the final state.
  Future<void> cancelSubscription() async {
    final currentUser = AppAuth.currentUser;
    if (currentUser == null) {
      throw Exception(tr('submission_error_not_signed_in'));
    }

    final row = await _activeSubscriptionRow(currentUser.id);
    if (row == null) {
      throw Exception(tr('subscription_error_no_active_subscription'));
    }

    await _client.from('subscriptions').update({
      'auto_renew': false,
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', row['id']);
  }

  Subscription _freePlaceholder(String userId) {
    final now = DateTime.now();
    return Subscription(
      id: '',
      userId: userId,
      type: SubscriptionType.free,
      status: SubscriptionStatus.active,
      startDate: now,
      endDate: now,
      price: 0,
      features: const {},
    );
  }

  Future<Map<String, dynamic>?> _activeSubscriptionRow(String userId) async {
    return await _client
        .from('subscriptions')
        .select('*, subscription_plans(code, price_monthly)')
        .eq('user_id', userId)
        .inFilter('status', ['trial', 'active'])
        .order('starts_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Subscription _toSubscription(Map<String, dynamic> row) {
    final plan = row['subscription_plans'] as Map<String, dynamic>?;
    final code = (plan?['code'] ?? 'free').toString();
    return Subscription.fromSupabase(row: row, planCode: code);
  }
}
