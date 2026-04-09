import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/models/challenge.dart';

import '../../domain/repositories/challenge_repository.dart';
import 'challenges_event.dart';
import 'challenges_state.dart';

class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  ChallengesBloc(this._repository) : super(const ChallengesInitial()) {
    on<ChallengesStarted>(_onStarted);
  }

  final ChallengeRepository _repository;
  StreamSubscription<List<Challenge>>? _subscription;

  Future<void> _onStarted(
    ChallengesStarted event,
    Emitter<ChallengesState> emit,
  ) async {
    await _subscription?.cancel();
    emit(const ChallengesLoading());
    _subscription = _repository.watchChallenges(limit: 50).listen(
      (challenges) {
        if (!isClosed) {
          emit(ChallengesReady(challenges));
        }
      },
      onError: (Object err, StackTrace st) {
        if (!isClosed) {
          emit(ChallengesFailure(err.toString()));
        }
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
