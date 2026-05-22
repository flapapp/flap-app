import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/challenge.dart';
import '../../domain/repositories/challenges_repository.dart';
import 'challenge_catalog_state.dart';

/// Bloc-managed [Challenge] list for the dedicated challenge list screen.
class ChallengeCatalogCubit extends Cubit<ChallengeCatalogState> {
  ChallengeCatalogCubit(this._repository) : super(const ChallengeCatalogState());

  final ChallengesRepository _repository;

  void updateFilters({
    String? selectedStatus,
    String? selectedType,
    String? selectedCity,
    String? searchQuery,
  }) {
    emit(
      state.copyWith(
        selectedStatus: selectedStatus,
        selectedType: selectedType,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
      ),
    );
  }

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(status: ChallengeCatalogStatus.loading, clearError: true));
    try {
      List<Challenge> challenges;
      if (state.selectedStatus != 'all') {
        final status = ChallengeStatus.values.firstWhere(
          (s) => s.name == state.selectedStatus,
          orElse: () => ChallengeStatus.recruiting,
        );
        challenges = await _repository.fetchChallengesByStatus(status);
      } else if (state.selectedType != 'all') {
        final type = parseChallengeType(state.selectedType);
        challenges = await _repository.fetchChallengesByType(type);
      } else if (state.selectedCity.isNotEmpty) {
        challenges = await _repository.fetchChallengesByCity(state.selectedCity);
      } else {
        challenges = await _repository.fetchActiveChallenges();
      }
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ChallengeCatalogStatus.ready,
            challenges: challenges,
            clearError: true,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ChallengeCatalogStatus.error,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }
}
