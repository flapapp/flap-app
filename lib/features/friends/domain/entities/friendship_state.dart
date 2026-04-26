/// Snapshot of the relationship between the current user and [otherUserId].
class FriendshipState {
  const FriendshipState({
    required this.isFriend,
    this.incomingPendingRequestId,
    this.outgoingPendingRequestId,
  });

  final bool isFriend;

  /// The other user sent a pending request to the current user.
  final String? incomingPendingRequestId;

  /// The current user sent a pending request to the other user.
  final String? outgoingPendingRequestId;

  bool get hasPendingOutgoing => outgoingPendingRequestId != null;

  bool get hasPendingIncoming => incomingPendingRequestId != null;
}
