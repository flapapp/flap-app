import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_auth.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/interactions/interaction_store.dart';
import '../../data/models/challenge.dart' show computeChallengePrizePoolCoins;

/// Loads challenge submissions, the current user's ratings, and the header
/// metadata (participant count, submission count, prize pool, entry fee) via
/// standard selects.
///
/// [load] fetches everything together, so a single [refresh] updates the whole
/// page. The screen already refreshes after the two actions that can change
/// these numbers — returning from the video player and from an upload — and
/// the entry fee only moves on an admin/creator edit, which a reopen picks up.
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
       ));

  final String _challengeId;
  final String _challengeCreatorId;
  SupabaseClient get _sb => Supabase.instance.client;

  /// Entry fee (drives the prize pool) and the participant ids/count.
  /// Submission count comes from the submissions [load] already fetches.
  Future<({int entryFee, List<String> participantIds})> _fetchMetadata() async {
    final challengeRow = await _sb
        .from('challenges')
        .select('entry_fee')
        .eq('id', _challengeId)
        .maybeSingle();
    final participantRows = await _sb
        .from('challenge_participants')
        .select('user_id')
        .eq('challenge_id', _challengeId);
    final ids = (participantRows as List<dynamic>)
        .map((r) => (r as Map<String, dynamic>)['user_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    return (
      entryFee: (challengeRow?['entry_fee'] as num?)?.toInt() ?? state.entryFee,
      participantIds: ids,
    );
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
      // Header metadata, previously three realtime subscriptions.
      final metadata = _challengeId.isEmpty ? null : await _fetchMetadata();

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

      // Seed the centralized store so submission cards (and the challenge
      // video player) share one reactive source for vote avg/count/voted.
      final store = sl<InteractionStore>();
      for (final submission in list) {
        final sid = submission['id']?.toString() ?? '';
        if (sid.isEmpty) continue;
        store.seedRating(
          sid,
          ratingAvg: ((submission['averageRating'] as num?) ?? 0).toDouble(),
          voteCount: (submission['voteCount'] as int?) ?? 0,
          votedByMe: myRatings.containsKey(sid),
        );
      }

      final participantIds = metadata?.participantIds ?? state.participantIds;
      final entryFee = metadata?.entryFee ?? state.entryFee;

      emit(
        state.copyWith(
          submissions: list,
          myRatingsBySubmissionId: myRatings,
          submitterProfilesByUserId: submitterProfiles,
          isLoading: false,
          error: null,
          loadedChallengeId: _challengeId,
          participantCount: participantIds.length,
          participantIds: participantIds,
          submissionCount: list.length,
          entryFee: entryFee,
          prizePool: computeChallengePrizePoolCoins(
            participantCount: participantIds.length,
            entryFee: entryFee,
          ),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> refresh() => load(force: true);

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

  /// Counts/values read by [ChallengeDetailsCubit.load]. The screen reads
  /// these instead of the static `Challenge` entity passed via constructor,
  /// so header chips reflect the database once the page loads or refreshes.
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
