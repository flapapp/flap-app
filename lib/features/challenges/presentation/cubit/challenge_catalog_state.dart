import 'package:equatable/equatable.dart';

import '../../data/models/challenge.dart';

enum ChallengeCatalogStatus { initial, loading, ready, error }

class ChallengeCatalogState extends Equatable {
  const ChallengeCatalogState({
    this.status = ChallengeCatalogStatus.initial,
    this.challenges = const [],
    this.errorMessage,
    this.selectedStatus = 'all',
    this.selectedType = 'all',
    this.selectedCity = '',
    this.searchQuery = '',
  });

  final ChallengeCatalogStatus status;
  final List<Challenge> challenges;
  final String? errorMessage;
  final String selectedStatus;
  final String selectedType;
  final String selectedCity;
  final String searchQuery;

  bool get isLoading => status == ChallengeCatalogStatus.loading;

  List<Challenge> get filteredChallenges {
    var list = challenges;
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(query) ||
                c.description.toLowerCase().contains(query) ||
                c.creatorName.toLowerCase().contains(query) ||
                c.city.toLowerCase().contains(query),
          )
          .toList(growable: false);
    }
    return list;
  }

  ChallengeCatalogState copyWith({
    ChallengeCatalogStatus? status,
    List<Challenge>? challenges,
    String? errorMessage,
    String? selectedStatus,
    String? selectedType,
    String? selectedCity,
    String? searchQuery,
    bool clearError = false,
  }) {
    return ChallengeCatalogState(
      status: status ?? this.status,
      challenges: challenges ?? this.challenges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedType: selectedType ?? this.selectedType,
      selectedCity: selectedCity ?? this.selectedCity,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        status,
        challenges,
        errorMessage,
        selectedStatus,
        selectedType,
        selectedCity,
        searchQuery,
      ];
}
