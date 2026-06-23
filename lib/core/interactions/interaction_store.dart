import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/app_auth.dart';

/// Immutable per-content interaction snapshot shared across every screen that
/// shows the same video or challenge submission.
@immutable
class ContentInteraction {
  final int likeCount;
  final bool likedByMe;
  final int commentCount;
  final double ratingAvg;
  final int voteCount;
  final bool votedByMe;

  /// `false` until the first authoritative fetch/seed completes. Widgets can
  /// show a placeholder while unloaded.
  final bool loaded;

  const ContentInteraction({
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
    this.ratingAvg = 0.0,
    this.voteCount = 0,
    this.votedByMe = false,
    this.loaded = false,
  });

  ContentInteraction copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
    double? ratingAvg,
    int? voteCount,
    bool? votedByMe,
    bool? loaded,
  }) {
    return ContentInteraction(
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount ?? this.commentCount,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      voteCount: voteCount ?? this.voteCount,
      votedByMe: votedByMe ?? this.votedByMe,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ContentInteraction &&
      other.likeCount == likeCount &&
      other.likedByMe == likedByMe &&
      other.commentCount == commentCount &&
      other.ratingAvg == ratingAvg &&
      other.voteCount == voteCount &&
      other.votedByMe == votedByMe &&
      other.loaded == loaded;

  @override
  int get hashCode => Object.hash(likeCount, likedByMe, commentCount, ratingAvg,
      voteCount, votedByMe, loaded);
}

enum _ContentKind { video, submission }

/// Centralized, reactive source of truth for likes, comment counts and
/// vote/rating aggregates, keyed by content id. Any widget binds to a content
/// id via [watchVideo]/[watchSubmission] (a [ValueListenable]); a mutation from
/// any screen updates the single shared notifier so every subscriber rebuilds
/// instantly. Registered as a GetIt singleton (see `injection.dart`), mirroring
/// the existing `VideoFeedSync`.
class InteractionStore {
  final SupabaseClient _sb = Supabase.instance.client;

  final Map<String, ValueNotifier<ContentInteraction>> _notifiers = {};
  final Map<String, _ContentKind> _kinds = {};
  final Set<String> _inFlight = {};

  ValueNotifier<ContentInteraction> _notifierFor(String id) {
    return _notifiers.putIfAbsent(
        id, () => ValueNotifier(const ContentInteraction()));
  }

  /// Subscribe to a video's interaction state, lazily fetching once if unseen.
  ValueListenable<ContentInteraction> watchVideo(String videoId) {
    _kinds[videoId] = _ContentKind.video;
    final n = _notifierFor(videoId);
    if (!n.value.loaded) _ensureLoaded(videoId, _ContentKind.video);
    return n;
  }

  /// Subscribe to a challenge submission's vote state, lazily fetching once.
  ValueListenable<ContentInteraction> watchSubmission(String submissionId) {
    _kinds[submissionId] = _ContentKind.submission;
    final n = _notifierFor(submissionId);
    if (!n.value.loaded) _ensureLoaded(submissionId, _ContentKind.submission);
    return n;
  }

  /// Current snapshot without subscribing (for imperative reads).
  ContentInteraction peek(String id) =>
      _notifiers[id]?.value ?? const ContentInteraction();

  // --- seeding (authoritative bulk fill from list/detail loads) -------------

  void seed(String id, ContentInteraction value) {
    _notifierFor(id).value = value.copyWith(loaded: true);
  }

  void seedMany(Map<String, ContentInteraction> values) {
    values.forEach(seed);
  }

  /// Merge only the provided fields (authoritative), leaving the rest intact.
  /// Useful when a screen only knows some of a content's interaction values.
  void mergeContent(
    String id, {
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
    double? ratingAvg,
    int? voteCount,
    bool? votedByMe,
  }) {
    _merge(id, (p) => p.copyWith(
          likeCount: likeCount,
          likedByMe: likedByMe,
          commentCount: commentCount,
          ratingAvg: ratingAvg,
          voteCount: voteCount,
          votedByMe: votedByMe,
          loaded: true,
        ));
  }

  /// Merge only the like fields from a list/detail load without clobbering
  /// rating/comment fields another screen may already have populated.
  void seedLike(String id, {required int likeCount, required bool likedByMe}) {
    _merge(id, (p) => p.copyWith(
        likeCount: likeCount, likedByMe: likedByMe, loaded: true));
  }

  void seedCommentCount(String id, int commentCount) {
    _merge(id, (p) => p.copyWith(commentCount: commentCount, loaded: true));
  }

  void seedRating(String id,
      {required double ratingAvg,
      required int voteCount,
      required bool votedByMe}) {
    _merge(id, (p) => p.copyWith(
        ratingAvg: ratingAvg,
        voteCount: voteCount,
        votedByMe: votedByMe,
        loaded: true));
  }

  // --- optimistic mutators (instant UI before persistence) ------------------

  void applyLikeOptimistic(String id, {required bool likedByMe}) {
    _merge(id, (p) {
      final delta = likedByMe ? 1 : -1;
      return p.copyWith(
        likedByMe: likedByMe,
        likeCount: (p.likeCount + delta).clamp(0, 1 << 30),
        loaded: true,
      );
    });
  }

  void applyCommentDelta(String id, int delta) {
    _merge(id, (p) => p.copyWith(
        commentCount: (p.commentCount + delta).clamp(0, 1 << 30),
        loaded: true));
  }

  void applyVoteOptimistic(String id,
      {required double newAvg, required int newVoteCount}) {
    _merge(id, (p) => p.copyWith(
        ratingAvg: newAvg,
        voteCount: newVoteCount,
        votedByMe: true,
        loaded: true));
  }

  // --- reconcilers (authoritative values after persistence) -----------------

  void reconcileLike(String id, {required int likeCount, required bool likedByMe}) {
    _merge(id, (p) => p.copyWith(
        likeCount: likeCount, likedByMe: likedByMe, loaded: true));
  }

  void reconcileComment(String id, int commentCount) {
    _merge(id, (p) => p.copyWith(commentCount: commentCount, loaded: true));
  }

  void reconcileVote(String id,
      {required double ratingAvg,
      required int voteCount,
      required bool votedByMe}) {
    _merge(id, (p) => p.copyWith(
        ratingAvg: ratingAvg,
        voteCount: voteCount,
        votedByMe: votedByMe,
        loaded: true));
  }

  /// Restore a previously-captured snapshot (optimistic rollback on failure).
  void restore(String id, ContentInteraction previous) {
    _notifierFor(id).value = previous;
  }

  /// Clear all state — call on sign-out so per-user flags don't leak.
  void clear() {
    for (final n in _notifiers.values) {
      n.value = const ContentInteraction();
    }
    _notifiers.clear();
    _kinds.clear();
    _inFlight.clear();
  }

  // --- internals ------------------------------------------------------------

  void _merge(String id, ContentInteraction Function(ContentInteraction) f) {
    final n = _notifierFor(id);
    final next = f(n.value);
    if (next != n.value) n.value = next; // skip no-op rebuilds
  }

  Future<void> _ensureLoaded(String id, _ContentKind kind) async {
    if (_inFlight.contains(id)) return;
    _inFlight.add(id);
    try {
      if (kind == _ContentKind.video) {
        await _loadVideo(id);
      } else {
        await _loadSubmission(id);
      }
    } catch (_) {
      // Non-fatal: leave placeholder; a later seed/mutation can fill it in.
    } finally {
      _inFlight.remove(id);
    }
  }

  Future<void> _loadVideo(String id) async {
    final uid = AppAuth.currentUserId;

    final likeRows =
        await _sb.from('video_likes').select('user_id').eq('video_id', id);
    final likes = (likeRows as List<dynamic>);
    final likeCount = likes.length;
    final likedByMe = uid != null &&
        likes.any((r) => (r as Map<String, dynamic>)['user_id'] == uid);

    final commentRows =
        await _sb.from('video_comments').select('id').eq('video_id', id);
    final commentCount = (commentRows as List<dynamic>).length;

    final ratingRows = await _sb
        .from('video_ratings')
        .select('overall_rating, rated_by')
        .eq('video_id', id);
    final ratings = (ratingRows as List<dynamic>);
    final voteCount = ratings.length;
    double sum = 0.0;
    var votedByMe = false;
    for (final r in ratings) {
      final m = r as Map<String, dynamic>;
      sum += ((m['overall_rating'] as num?) ?? 0).toDouble();
      if (uid != null && m['rated_by'] == uid) votedByMe = true;
    }
    final avg = voteCount == 0
        ? 0.0
        : double.parse((sum / voteCount).toStringAsFixed(2));

    seed(
      id,
      ContentInteraction(
        likeCount: likeCount,
        likedByMe: likedByMe,
        commentCount: commentCount,
        ratingAvg: avg,
        voteCount: voteCount,
        votedByMe: votedByMe,
        loaded: true,
      ),
    );
  }

  Future<void> _loadSubmission(String id) async {
    final uid = AppAuth.currentUserId;
    final rows = await _sb
        .from('challenge_submission_ratings')
        .select('voter_user_id, overall_rating')
        .eq('challenge_submission_id', id);
    final list = (rows as List<dynamic>);
    final voteCount = list.length;
    double sum = 0.0;
    var votedByMe = false;
    for (final r in list) {
      final m = r as Map<String, dynamic>;
      sum += ((m['overall_rating'] as num?) ?? 0).toDouble();
      if (uid != null && m['voter_user_id'] == uid) votedByMe = true;
    }
    final avg = voteCount == 0
        ? 0.0
        : double.parse((sum / voteCount).toStringAsFixed(2));

    seedRating(id,
        ratingAvg: avg, voteCount: voteCount, votedByMe: votedByMe);
  }
}
