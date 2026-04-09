import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flap_app/core/app_auth_context.dart';
import 'package:flap_app/models/friend_request.dart';

import '../../domain/friend_failure.dart';
import '../../domain/repositories/friends_repository.dart';
import 'friends_event.dart';
import 'friends_state.dart';

class FriendsBloc extends Bloc<FriendsEvent, FriendsState> {
  FriendsBloc(this._repository) : super(const FriendsInitial()) {
    on<FriendsStarted>(_onStarted);
    on<FriendsIncomingUpdated>(_onIncomingUpdated);
    on<FriendsOutgoingUpdated>(_onOutgoingUpdated);
    on<FriendsLoadFriendsRequested>(_onLoadFriendsRequested);
    on<FriendsSearchRequested>(_onSearchRequested);
    on<FriendsSendFriendRequest>(_onSendFriendRequest);
    on<FriendsRespondToRequest>(_onRespondToRequest);
    on<FriendsCancelRequest>(_onCancelRequest);
    on<FriendsRemoveFriend>(_onRemoveFriend);
    on<FriendsClearMessages>(_onClearMessages);
  }

  final FriendsRepository _repository;
  StreamSubscription<List<FriendRequest>>? _incomingSub;
  StreamSubscription<List<FriendRequest>>? _outgoingSub;

  Future<void> _onStarted(FriendsStarted event, Emitter<FriendsState> emit) async {
    await _incomingSub?.cancel();
    await _outgoingSub?.cancel();
    emit(FriendsReady.initial());

    final uid = AppAuthContext.userId;
    if (uid == null) {
      emit((state as FriendsReady).copyWith(loadingFriends: false));
      return;
    }

    _incomingSub = _repository.watchIncomingFriendRequests().listen(
      (list) => add(FriendsIncomingUpdated(list)),
      onError: (Object e, StackTrace _) {
        final cur = state;
        if (cur is FriendsReady) {
          emit(cur.copyWith(errorMessage: e.toString()));
        }
      },
    );

    _outgoingSub = _repository.watchOutgoingFriendRequests().listen(
      (list) => add(FriendsOutgoingUpdated(list)),
      onError: (Object e, StackTrace _) {
        final cur = state;
        if (cur is FriendsReady) {
          emit(cur.copyWith(errorMessage: e.toString()));
        }
      },
    );

    add(const FriendsLoadFriendsRequested());
  }

  void _onIncomingUpdated(
    FriendsIncomingUpdated event,
    Emitter<FriendsState> emit,
  ) {
    final cur = state;
    if (cur is FriendsReady) {
      emit(cur.copyWith(incoming: event.requests));
    }
  }

  void _onOutgoingUpdated(
    FriendsOutgoingUpdated event,
    Emitter<FriendsState> emit,
  ) {
    final cur = state;
    if (cur is FriendsReady) {
      emit(cur.copyWith(outgoing: event.requests));
    }
  }

  Future<void> _onLoadFriendsRequested(
    FriendsLoadFriendsRequested event,
    Emitter<FriendsState> emit,
  ) async {
    final uid = AppAuthContext.userId;
    final cur = state;
    if (cur is! FriendsReady) return;
    if (uid == null) {
      emit(cur.copyWith(loadingFriends: false));
      return;
    }
    try {
      final friends = await _repository.getUserFriends(uid);
      final after = state;
      if (after is FriendsReady) {
        emit(after.copyWith(friends: friends, loadingFriends: false));
      }
    } on FriendFailure catch (e) {
      final after = state;
      if (after is FriendsReady) {
        emit(after.copyWith(loadingFriends: false, errorMessage: e.message));
      }
    } catch (e) {
      final after = state;
      if (after is FriendsReady) {
        emit(after.copyWith(loadingFriends: false, errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onSearchRequested(
    FriendsSearchRequested event,
    Emitter<FriendsState> emit,
  ) async {
    final cur = state;
    if (cur is! FriendsReady) return;
    if (event.query.trim().length < 2) {
      emit(cur.copyWith(searchResults: [], searchLoading: false));
      return;
    }
    emit(cur.copyWith(searchLoading: true));
    try {
      final results = await _repository.searchUsers(event.query);
      final after = state;
      if (after is FriendsReady) {
        emit(after.copyWith(searchResults: results, searchLoading: false));
      }
    } on FriendFailure catch (e) {
      final after = state;
      if (after is FriendsReady) {
        emit(after.copyWith(searchLoading: false, errorMessage: e.message));
      }
    } catch (e) {
      final after = state;
      if (after is FriendsReady) {
        emit(after.copyWith(searchLoading: false, errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onSendFriendRequest(
    FriendsSendFriendRequest event,
    Emitter<FriendsState> emit,
  ) async {
    try {
      await _repository.sendFriendRequest(event.userId);
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(successMessage: 'invitation_sent'));
      }
    } on FriendFailure catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.message));
      }
    } catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onRespondToRequest(
    FriendsRespondToRequest event,
    Emitter<FriendsState> emit,
  ) async {
    try {
      await _repository.respondToFriendRequest(event.requestId, event.accept);
      if (event.accept) {
        add(const FriendsLoadFriendsRequested());
      }
      final cur = state;
      if (cur is FriendsReady) {
        emit(
          cur.copyWith(
            successMessage: event.accept ? 'invitation_accepted' : 'invitation_declined',
          ),
        );
      }
    } on FriendFailure catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.message));
      }
    } catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onCancelRequest(
    FriendsCancelRequest event,
    Emitter<FriendsState> emit,
  ) async {
    try {
      await _repository.cancelFriendRequest(event.requestId);
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(successMessage: 'invitation_cancelled'));
      }
    } on FriendFailure catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.message));
      }
    } catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.toString()));
      }
    }
  }

  Future<void> _onRemoveFriend(
    FriendsRemoveFriend event,
    Emitter<FriendsState> emit,
  ) async {
    try {
      await _repository.removeFriend(event.friendUserId);
      add(const FriendsLoadFriendsRequested());
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(successMessage: 'removed:${event.friendName}'));
      }
    } on FriendFailure catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.message));
      }
    } catch (e) {
      final cur = state;
      if (cur is FriendsReady) {
        emit(cur.copyWith(errorMessage: e.toString()));
      }
    }
  }

  void _onClearMessages(FriendsClearMessages event, Emitter<FriendsState> emit) {
    final cur = state;
    if (cur is FriendsReady) {
      emit(cur.copyWith(errorMessage: null, successMessage: null));
    }
  }

  @override
  Future<void> close() {
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    return super.close();
  }
}
