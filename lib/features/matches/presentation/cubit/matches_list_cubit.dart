import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/auth/app_auth.dart';

import '../../data/models/match.dart';
import '../../domain/repositories/matches_repository.dart';
import 'matches_list_state.dart';

/// Bloc-managed match lists (find-match feed, my matches, history).
class MatchesListCubit extends Cubit<MatchesListState> {
  MatchesListCubit(this._repository) : super(const MatchesListState());

  final MatchesRepository _repository;

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: MatchesListStatus.loading, clearError: true));
    try {
      final uid = AppAuth.currentUserId;
      final available = await _repository.fetchAvailableMatches();
      final List<Match> user = uid != null
          ? await _repository.fetchUserMatches(uid)
          : const [];
      if (isClosed) return;
      emit(
        state.copyWith(
          status: MatchesListStatus.ready,
          availableMatches: available,
          userMatches: user,
          clearError: true,
        ),
      );
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: MatchesListStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }
}
