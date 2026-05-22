import 'package:equatable/equatable.dart';

enum ChallengesListStatus { initial, loading, ready, error }

class ChallengesListState extends Equatable {
  const ChallengesListState({
    this.status = ChallengesListStatus.initial,
    this.items = const [],
    this.errorMessage,
    this.onlyCreatorUserId,
  });

  final ChallengesListStatus status;
  final List<Map<String, dynamic>> items;
  final String? errorMessage;
  final String? onlyCreatorUserId;

  bool get isLoading => status == ChallengesListStatus.loading;

  ChallengesListState copyWith({
    ChallengesListStatus? status,
    List<Map<String, dynamic>>? items,
    String? errorMessage,
    String? onlyCreatorUserId,
    bool clearError = false,
  }) {
    return ChallengesListState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      onlyCreatorUserId: onlyCreatorUserId ?? this.onlyCreatorUserId,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage, onlyCreatorUserId];
}
