import 'package:bloc/bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_auth.dart';

/// Loads challenge submissions and the current user's ratings via standard selects
/// (no Realtime `.stream`), with optional refresh after mutations.
class ChallengeDetailsCubit extends Cubit<ChallengeDetailsState> {
  ChallengeDetailsCubit(
    this._challengeId, {
    String? challengeCreatorId,
  })  : _challengeCreatorId = challengeCreatorId ?? '',
        super(const ChallengeDetailsState());

  final String _challengeId;
  final String _challengeCreatorId;
  SupabaseClient get _sb => Supabase.instance.client;

  /// Loads data. Skips network if [force] is false and we already have rows for this challenge.
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

      emit(ChallengeDetailsState(
        submissions: list,
        myRatingsBySubmissionId: myRatings,
        isLoading: false,
        error: null,
        loadedChallengeId: _challengeId,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
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
      'isCreatorVideo': _challengeCreatorId.isNotEmpty && uid == _challengeCreatorId,
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
    this.isLoading = false,
    this.error,
    this.loadedChallengeId,
  });

  final List<Map<String, dynamic>> submissions;
  final Map<String, Map<String, dynamic>> myRatingsBySubmissionId;
  final bool isLoading;
  final String? error;
  final String? loadedChallengeId;

  ChallengeDetailsState copyWith({
    List<Map<String, dynamic>>? submissions,
    Map<String, Map<String, dynamic>>? myRatingsBySubmissionId,
    bool? isLoading,
    String? error,
    String? loadedChallengeId,
  }) {
    return ChallengeDetailsState(
      submissions: submissions ?? this.submissions,
      myRatingsBySubmissionId:
          myRatingsBySubmissionId ?? this.myRatingsBySubmissionId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      loadedChallengeId: loadedChallengeId ?? this.loadedChallengeId,
    );
  }
}
