import 'package:flutter/foundation.dart';

import 'package:flap_app/core/auth/app_auth.dart';

import '../data/models/subscription.dart';
import 'repositories/subscriptions_repository.dart';

/// A resolved snapshot of the signed-in user's subscription access.
@immutable
class SubscriptionSnapshot {
  const SubscriptionSnapshot._(this.resolved, this.subscription);

  /// Not yet loaded for the current user.
  const SubscriptionSnapshot.loading() : this._(false, null);

  /// Loaded: no premium subscription (view-only).
  const SubscriptionSnapshot.free() : this._(true, null);

  /// Loaded with the user's subscription row.
  const SubscriptionSnapshot.resolved(Subscription? subscription)
      : this._(true, subscription);

  /// Whether we have finished loading state for the current user.
  final bool resolved;
  final Subscription? subscription;

  bool get isPremium => subscription?.isPremiumActive ?? false;
}

/// Single source of truth for "does this user have premium access?", cached in
/// memory and refreshed after checkout, on login, and on app resume.
///
/// The cache is per-user and MUST be cleared on sign-out (see
/// [AppAuth.signOut]) so the next user doesn't inherit premium access.
class SubscriptionAccess {
  SubscriptionAccess(this._repo);

  final SubscriptionsRepository _repo;

  final ValueNotifier<SubscriptionSnapshot> notifier =
      ValueNotifier(const SubscriptionSnapshot.loading());

  SubscriptionSnapshot get snapshot => notifier.value;

  Subscription? get current => notifier.value.subscription;

  /// True only when we have loaded state AND it grants premium.
  bool get isPremium => notifier.value.isPremium;

  bool get isResolved => notifier.value.resolved;

  /// Re-query the user's subscription and publish the result.
  Future<void> refresh() async {
    final userId = AppAuth.currentUserId;
    if (userId == null) {
      notifier.value = const SubscriptionSnapshot.free();
      return;
    }
    try {
      final sub = await _repo.getUserSubscription(userId);
      notifier.value = SubscriptionSnapshot.resolved(sub);
    } catch (e) {
      // On error, fail closed to view-only rather than falsely granting access.
      notifier.value = const SubscriptionSnapshot.free();
    }
  }

  /// Ensure state is loaded at least once, without forcing a re-query.
  Future<void> ensureLoaded() async {
    if (!notifier.value.resolved) await refresh();
  }

  /// Poll a few times after checkout: the Paddle webhook writes the row
  /// asynchronously, so premium may not be visible on the first read.
  Future<bool> refreshUntilPremium({
    int tries = 6,
    Duration interval = const Duration(seconds: 2),
  }) async {
    for (var i = 0; i < tries; i++) {
      await refresh();
      if (isPremium) return true;
      if (i < tries - 1) await Future.delayed(interval);
    }
    return isPremium;
  }

  /// Wipe cached state on sign-out so it can't leak into the next session.
  void clear() {
    notifier.value = const SubscriptionSnapshot.loading();
  }
}
