import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flap_app/core/auth/app_auth.dart';

import '../../data/models/friend_request.dart';
import '../../domain/repositories/friends_repository.dart';
import 'friends_page_state.dart';

/// Owns friends, incoming, and outgoing tab snapshots (fetch on load / after mutations).
class FriendsPageCubit extends Cubit<FriendsPageState> {
  FriendsPageCubit(this._repository) : super(const FriendsPageState());

  final FriendsRepository _repository;

  Future<void> load() async {
    final uid = AppAuth.currentUser?.id;
    if (uid == null) {
      if (!isClosed) emit(const FriendsPageState(friendsLoading: false));
      return;
    }

    if (!isClosed) emit(state.copyWith(friendsLoading: true));
    await refreshAll();
  }

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

  @override
  Future<void> close() async {
    return super.close();
  }
}
