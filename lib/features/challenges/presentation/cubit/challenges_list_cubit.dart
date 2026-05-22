import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/challenges_repository.dart';
import 'challenges_list_state.dart';

/// Bloc-managed challenge list rows for card UIs (hub / challenges tab).
class ChallengesListCubit extends Cubit<ChallengesListState> {
  ChallengesListCubit(this._repository) : super(const ChallengesListState());

  final ChallengesRepository _repository;

  Future<void> load({String? onlyCreatorUserId, int limit = 50}) async {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: ChallengesListStatus.loading,
        onlyCreatorUserId: onlyCreatorUserId,
        clearError: true,
      ),
    );
    try {
      final items = await _repository.fetchChallengesForListUi(
        limit: limit,
        onlyCreatorUserId: onlyCreatorUserId,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ChallengesListStatus.ready,
            items: items,
            clearError: true,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ChallengesListStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }
}
