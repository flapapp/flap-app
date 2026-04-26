import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flap_app/core/auth/app_auth.dart';

import '../../data/models/friend_request.dart';
import '../../domain/repositories/friends_repository.dart';
import 'friends_page_state.dart';

/// Owns subscriptions and snapshots for friends, incoming, and outgoing tabs.
class FriendsPageCubit extends Cubit<FriendsPageState> {
  FriendsPageCubit(this._repository, this._supabase)
      : super(const FriendsPageState());

  final FriendsRepository _repository;
  final SupabaseClient _supabase;

  StreamSubscription<List<FriendRequest>>? _incomingSub;
  StreamSubscription<List<FriendRequest>>? _outgoingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _friendshipsSub;

  /// Start initial load, then listen to Supabase realtime + request streams.
  Future<void> subscribe() async {
    final uid = AppAuth.currentUser?.id;
    if (uid == null) {
      if (!isClosed) emit(const FriendsPageState(friendsLoading: false));
      return;
    }

    if (!isClosed) emit(state.copyWith(friendsLoading: true));
    await refreshAll();
    if (!isClosed) await _attachStreams(uid);
  }

  Future<void> _attachStreams(String uid) async {
    await _incomingSub?.cancel();
    await _outgoingSub?.cancel();
    await _friendshipsSub?.cancel();

    _incomingSub = _repository.getIncomingFriendRequests().listen(
      (list) {
        if (!isClosed) emit(state.copyWith(incomingRequests: list));
      },
      onError: (_) {},
    );

    _outgoingSub = _repository.getOutgoingFriendRequests().listen(
      (list) {
        if (!isClosed) emit(state.copyWith(outgoingRequests: list));
      },
      onError: (_) {},
    );

    _friendshipsSub = _supabase
        .from('friendships')
        .stream(primaryKey: const ['id'])
        .eq('user_id', uid)
        .listen((_) {
      if (!isClosed) unawaited(refreshFriendsOnly());
    }, onError: (_) {});
  }

  /// Reload all three lists from the backend (after mutations; avoids realtime lag).
  Future<void> refreshAll() async {
    final uid = AppAuth.currentUser?.id;
    if (uid == null) return;

    try {
      final results = await Future.wait([
        _repository.getUserFriends(uid),
        _repository.fetchPendingIncomingFriendRequests(),
        _repository.fetchPendingOutgoingFriendRequests(),
      ]);
      if (!isClosed) {
        emit(
          state.copyWith(
            friends: results[0] as List<Friend>,
            incomingRequests: results[1] as List<FriendRequest>,
            outgoingRequests: results[2] as List<FriendRequest>,
            friendsLoading: false,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(friendsLoading: false));
    }
  }

  Future<void> refreshFriendsOnly() async {
    final uid = AppAuth.currentUser?.id;
    if (uid == null) return;
    try {
      final friends = await _repository.getUserFriends(uid);
      if (!isClosed) {
        emit(state.copyWith(friends: friends, friendsLoading: false));
      }
    } catch (_) {
      if (!isClosed) emit(state.copyWith(friendsLoading: false));
    }
  }

  @override
  Future<void> close() async {
    await _incomingSub?.cancel();
    await _outgoingSub?.cancel();
    await _friendshipsSub?.cancel();
    return super.close();
  }
}
