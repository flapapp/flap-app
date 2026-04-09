import 'package:equatable/equatable.dart';
import 'package:flap_app/models/friend_request.dart';

abstract class FriendsState extends Equatable {
  const FriendsState();

  @override
  List<Object?> get props => [];
}

class FriendsInitial extends FriendsState {
  const FriendsInitial();
}

const Object _sentinel = Object();

class FriendsReady extends FriendsState {
  const FriendsReady({
    required this.friends,
    required this.incoming,
    required this.outgoing,
    required this.loadingFriends,
    this.searchLoading = false,
    this.searchResults = const [],
    this.errorMessage,
    this.successMessage,
  });

  final List<Friend> friends;
  final List<FriendRequest> incoming;
  final List<FriendRequest> outgoing;
  final bool loadingFriends;
  final bool searchLoading;
  final List<Map<String, dynamic>> searchResults;
  final String? errorMessage;
  final String? successMessage;

  factory FriendsReady.initial() => const FriendsReady(
        friends: [],
        incoming: [],
        outgoing: [],
        loadingFriends: true,
      );

  @override
  List<Object?> get props => [
        friends,
        incoming,
        outgoing,
        loadingFriends,
        searchLoading,
        searchResults,
        errorMessage,
        successMessage,
      ];

  FriendsReady copyWith({
    List<Friend>? friends,
    List<FriendRequest>? incoming,
    List<FriendRequest>? outgoing,
    bool? loadingFriends,
    bool? searchLoading,
    List<Map<String, dynamic>>? searchResults,
    Object? errorMessage = _sentinel,
    Object? successMessage = _sentinel,
  }) {
    return FriendsReady(
      friends: friends ?? this.friends,
      incoming: incoming ?? this.incoming,
      outgoing: outgoing ?? this.outgoing,
      loadingFriends: loadingFriends ?? this.loadingFriends,
      searchLoading: searchLoading ?? this.searchLoading,
      searchResults: searchResults ?? this.searchResults,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
      successMessage: successMessage == _sentinel
          ? this.successMessage
          : successMessage as String?,
    );
  }
}
