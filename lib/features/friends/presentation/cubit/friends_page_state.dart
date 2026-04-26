import 'package:equatable/equatable.dart';

import '../../data/models/friend_request.dart';

/// Single source of truth for the Friends screen tabs (lists + counts).
class FriendsPageState extends Equatable {
  const FriendsPageState({
    this.friends = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.friendsLoading = true,
  });

  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final List<FriendRequest> outgoingRequests;
  final bool friendsLoading;

  Set<String> get friendIds => friends.map((f) => f.userId).toSet();

  Set<String> get outgoingTargetUserIds =>
      outgoingRequests.map((r) => r.toUserId).toSet();

  Set<String> get incomingSenderUserIds =>
      incomingRequests.map((r) => r.fromUserId).toSet();

  /// Whether the current user can send a new friend request to [otherUserId].
  bool canSendFriendRequestTo(String otherUserId, String? currentUserId) {
    if (currentUserId == null || otherUserId == currentUserId) return false;
    return !friendIds.contains(otherUserId) &&
        !outgoingTargetUserIds.contains(otherUserId) &&
        !incomingSenderUserIds.contains(otherUserId);
  }

  FriendsPageState copyWith({
    List<Friend>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    bool? friendsLoading,
  }) {
    return FriendsPageState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
      friendsLoading: friendsLoading ?? this.friendsLoading,
    );
  }

  @override
  List<Object?> get props =>
      [friends, incomingRequests, outgoingRequests, friendsLoading];
}
