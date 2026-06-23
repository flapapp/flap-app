import 'package:flutter/foundation.dart';

import '../di/injection.dart';
import '../../features/ratings/domain/repositories/ratings_repository.dart';

/// Immutable per-user overall-rating snapshot.
@immutable
class UserRating {
  final double value;

  /// `false` until the first fetch/seed resolves (widgets show a placeholder).
  final bool loaded;

  const UserRating({this.value = 0.0, this.loaded = false});

  @override
  bool operator ==(Object other) =>
      other is UserRating && other.value == value && other.loaded == loaded;

  @override
  int get hashCode => Object.hash(value, loaded);
}

/// Centralized, reactive source of truth for each user's overall rating, keyed
/// by userId. `RatingDisplay`/`CompactRatingDisplay` bind here so a rating
/// change anywhere (match rating, video vote → `RatingService` recompute)
/// refreshes every on-screen badge for that user. Registered as a GetIt
/// singleton.
class UserRatingStore {
  final Map<String, ValueNotifier<UserRating>> _notifiers = {};
  final Set<String> _inFlight = {};

  ValueNotifier<UserRating> _notifierFor(String userId) {
    return _notifiers.putIfAbsent(
        userId, () => ValueNotifier(const UserRating()));
  }

  /// Subscribe to a user's overall rating, lazily fetching once if unseen.
  ValueListenable<UserRating> watch(String userId) {
    final n = _notifierFor(userId);
    if (!n.value.loaded) _ensureLoaded(userId);
    return n;
  }

  /// Authoritative push (e.g. from `RatingService` after a recompute).
  void set(String userId, double value) {
    final n = _notifierFor(userId);
    final next = UserRating(value: value, loaded: true);
    if (next != n.value) n.value = next;
  }

  void seed(String userId, double value) => set(userId, value);

  /// Mark stale so the next [watch] refetches.
  void invalidate(String userId) {
    final n = _notifiers[userId];
    if (n != null) n.value = UserRating(value: n.value.value, loaded: false);
  }

  /// Re-read the authoritative rating and publish it.
  Future<void> refresh(String userId) async {
    try {
      final r = await sl<RatingsRepository>().getUserRating(userId);
      set(userId, r);
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Clear all state — call on sign-out.
  void clear() {
    for (final n in _notifiers.values) {
      n.value = const UserRating();
    }
    _notifiers.clear();
    _inFlight.clear();
  }

  Future<void> _ensureLoaded(String userId) async {
    if (_inFlight.contains(userId)) return;
    _inFlight.add(userId);
    try {
      final r = await sl<RatingsRepository>().getUserRating(userId);
      set(userId, r);
    } catch (_) {
      // Leave placeholder; a later set/refresh can fill it in.
    } finally {
      _inFlight.remove(userId);
    }
  }
}
