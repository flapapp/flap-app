import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../../core/supabase/guard_supabase_realtime_stream.dart';
import '../../data/models/challenge.dart' show computeChallengePrizePoolCoins;

/// Loads challenge submissions and the current user's ratings via standard
/// selects and keeps participant count, submission count, prize pool, and
/// entry fee live by subscribing to Supabase realtime streams.
///
/// Why three streams instead of one query?
///   * `challenges`              → entry fee can change (admin/edit) and
///                                  recomputes the prize pool.
///   * `challenge_participants`  → participant count drives the prize pool.
///   * `challenge_submissions`   → submission count drives the videos chip
///                                  on the detail page header.
///
/// All three are RLS-`select_all` for authenticated users (see
/// `20260423000001_flap_initial.sql`), so the join is safe and stays
/// reactive when other devices mutate the underlying rows.
class ChallengeDetailsCubit extends Cubit<ChallengeDetailsState> {
  ChallengeDetailsCubit(
    this._challengeId, {
    String? challengeCreatorId,
    int? initialEntryFee,
    int? initialParticipantCount,
    int? initialSubmissionCount,
  }) : _challengeCreatorId = challengeCreatorId ?? '',
       super(ChallengeDetailsState(
         entryFee: initialEntryFee ?? 0,
         participantCount: initialParticipantCount ?? 0,
         submissionCount: initialSubmissionCount ?? 0,
         prizePool: computeChallengePrizePoolCoins(
           participantCount: initialParticipantCount ?? 0,
           entryFee: initialEntryFee ?? 0,
         ),
       )) {
    _subscribeRealtimeMetadata();
  }

  final String _challengeId;
  final String _challengeCreatorId;
  SupabaseClient get _sb => Supabase.instance.client;

  StreamSubscription<List<Map<String, dynamic>>>? _challengeSub;
  StreamSubscription<List<Map<String, dynamic>>>? _participantsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _submissionsSub;

  /// Subscribes the cubit to live participant/submission counts and the
  /// current entry fee for this challenge so the detail screen header
  /// reflects the database state without manual refreshes.
  void _subscribeRealtimeMetadata() {
    if (_challengeId.isEmpty) return;

    _challengeSub = guardSupabaseRealtimeStream(
      _sb
          .from('challenges')
          .stream(primaryKey: ['id'])
          .eq('id', _challengeId),
    ).listen(_onChallengeRows, onError: (_) {});

    _participantsSub = guardSupabaseRealtimeStream(
      _sb
          .from('challenge_participants')
          .stream(primaryKey: ['challenge_id', 'user_id'])
          .eq('challenge_id', _challengeId),
    ).listen(_onParticipantsRows, onError: (_) {});

    _submissionsSub = guardSupabaseRealtimeStream(
      _sb
          .from('challenge_submissions')
          .stream(primaryKey: ['id'])
          .eq('challenge_id', _challengeId),
    ).listen(_onSubmissionsRows, onError: (_) {});
  }

  void _onChallengeRows(List<Map<String, dynamic>> rows) {
    if (isClosed || rows.isEmpty) return;
    final row = rows.first;
    final entryFee = (row['entry_fee'] as num?)?.toInt() ?? state.entryFee;
    if (entryFee == state.entryFee) return;
    emit(state.copyWith(
      entryFee: entryFee,
      prizePool: computeChallengePrizePoolCoins(
        participantCount: state.participantCount,
        entryFee: entryFee,
      ),
    ));
  }

  void _onParticipantsRows(List<Map<String, dynamic>> rows) {
    if (isClosed) return;
    final ids = rows
        .map((r) => r['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final count = ids.length;
    if (count == state.participantCount &&
        _listEquals(ids, state.participantIds)) {
      return;
    }
    emit(state.copyWith(
      participantCount: count,
      participantIds: ids,
      prizePool: computeChallengePrizePoolCoins(
        participantCount: count,
        entryFee: state.entryFee,
      ),
    ));
  }

  void _onSubmissionsRows(List<Map<String, dynamic>> rows) {
    if (isClosed) return;
    final count = rows.length;
    if (count != state.submissionCount) {
      emit(state.copyWith(submissionCount: count));
    }

    // Reload the full submission list (with ratings + submitter profiles) when
    // the *set* of submissions changes — e.g. the current user just uploaded an
    // entry — so the submissions grid and the upload dock update instantly
    // instead of only the header count.
    final liveIds = rows
        .map((r) => r['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false)
      ..sort();
    final loadedIds = state.submissions
        .map((s) => s['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false)
      ..sort();
    if (!state.isLoading && !_listEquals(liveIds, loadedIds)) {
      unawaited(load(force: true));
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Loads submissions and rating data. Skips network if [force] is false
  /// and we already have rows for this challenge.
  Future<void> load({bool force = false}) async {
    if (!force &&
        state.submissions.isNotEmpty &&
        state.loadedChallengeId == _challengeId &&
        !state.isLoading) {
      return;
    }
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final submissionsRows = await _sb
          .from('challenge_submissions')
          .select()
          .eq('challenge_id', _challengeId)
          .order('submitted_at', ascending: false);

      final list = (submissionsRows as List<dynamic>)
          .map((e) => _mapSubmissionRow(e as Map<String, dynamic>))
          .toList();

      final submissionIds = list
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      if (submissionIds.isNotEmpty) {
        final ratingsRows = await _sb
            .from('challenge_submission_ratings')
            .select('challenge_submission_id, overall_rating')
            .inFilter('challenge_submission_id', submissionIds);
        final totals = <String, double>{};
        final counts = <String, int>{};
        for (final raw in (ratingsRows as List<dynamic>)) {
          final row = raw as Map<String, dynamic>;
          final sid = row['challenge_submission_id']?.toString() ?? '';
          if (sid.isEmpty) continue;
          final val = ((row['overall_rating'] as num?) ?? 0).toDouble();
          totals[sid] = (totals[sid] ?? 0) + val;
          counts[sid] = (counts[sid] ?? 0) + 1;
        }
        for (final submission in list) {
          final sid = submission['id']?.toString() ?? '';
          final count = counts[sid] ?? 0;
          final total = totals[sid] ?? 0;
          submission['voteCount'] = count;
          submission['averageRating'] = count == 0 ? 0.0 : total / count;
        }
      }

      final uid = AppAuth.currentUserId;
      Map<String, Map<String, dynamic>> myRatings = {};
      if (uid != null && uid.isNotEmpty && submissionIds.isNotEmpty) {
        final ratingRows = await _sb
            .from('challenge_submission_ratings')
            .select()
            .inFilter('challenge_submission_id', submissionIds)
            .eq('voter_user_id', uid);
        for (final r in (ratingRows as List<dynamic>)) {
          final m = r as Map<String, dynamic>;
          final sid = m['challenge_submission_id']?.toString() ?? '';
          if (sid.isNotEmpty) {
            myRatings[sid] = Map<String, dynamic>.from(m);
          }
        }
      }

      final submitterIds = list
          .map((row) => row['userId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final submitterProfiles = <String, Map<String, dynamic>>{};
      if (submitterIds.isNotEmpty) {
        final profileRows = await _sb
            .from('profiles')
            .select('id,display_name,email,avatar_url')
            .inFilter('id', submitterIds);
        for (final raw in (profileRows as List<dynamic>)) {
          final row = raw as Map<String, dynamic>;
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            submitterProfiles[id] = row;
          }
        }
      }

      emit(
        state.copyWith(
          submissions: list,
          myRatingsBySubmissionId: myRatings,
          submitterProfilesByUserId: submitterProfiles,
          isLoading: false,
          error: null,
          loadedChallengeId: _challengeId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> refresh() => load(force: true);

  @override
  Future<void> close() async {
    await _challengeSub?.cancel();
    await _participantsSub?.cancel();
    await _submissionsSub?.cancel();
    return super.close();
  }

  Map<String, dynamic> _mapSubmissionRow(Map<String, dynamic> row) {
    final uid = row['user_id']?.toString() ?? '';
    return <String, dynamic>{
      'id': row['id']?.toString() ?? '',
      'title': row['title'] ?? '',
      'userId': uid,
      'videoUrl': row['video_url'] ?? '',
      'thumbnailUrl': row['thumbnail_url'] ?? '',
      'isCreatorVideo':
          _challengeCreatorId.isNotEmpty && uid == _challengeCreatorId,
      'averageRating': 0.0,
      'voteCount': 0,
      'createdAt': row['submitted_at'],
    };
  }
}

class ChallengeDetailsState {
  const ChallengeDetailsState({
    this.submissions = const [],
    this.myRatingsBySubmissionId = const {},
    this.submitterProfilesByUserId = const {},
    this.isLoading = false,
    this.error,
    this.loadedChallengeId,
    this.participantCount = 0,
    this.participantIds = const <String>[],
    this.submissionCount = 0,
    this.entryFee = 0,
    this.prizePool = 0,
  });

  final List<Map<String, dynamic>> submissions;
  final Map<String, Map<String, dynamic>> myRatingsBySubmissionId;
  final Map<String, Map<String, dynamic>> submitterProfilesByUserId;
  final bool isLoading;
  final String? error;
  final String? loadedChallengeId;

  /// Live counts/values fed by realtime streams. The screen reads these
  /// instead of the static `Challenge` entity passed via constructor so
  /// header chips refresh as participants join or videos are uploaded.
  final int participantCount;
  final List<String> participantIds;
  final int submissionCount;
  final int entryFee;
  final int prizePool;

  ChallengeDetailsState copyWith({
    List<Map<String, dynamic>>? submissions,
    Map<String, Map<String, dynamic>>? myRatingsBySubmissionId,
    Map<String, Map<String, dynamic>>? submitterProfilesByUserId,
    bool? isLoading,
    String? error,
    String? loadedChallengeId,
    int? participantCount,
    List<String>? participantIds,
    int? submissionCount,
    int? entryFee,
    int? prizePool,
  }) {
    return ChallengeDetailsState(
      submissions: submissions ?? this.submissions,
      myRatingsBySubmissionId:
          myRatingsBySubmissionId ?? this.myRatingsBySubmissionId,
      submitterProfilesByUserId:
          submitterProfilesByUserId ?? this.submitterProfilesByUserId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      loadedChallengeId: loadedChallengeId ?? this.loadedChallengeId,
      participantCount: participantCount ?? this.participantCount,
      participantIds: participantIds ?? this.participantIds,
      submissionCount: submissionCount ?? this.submissionCount,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
    );
  }
}
