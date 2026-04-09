import 'package:equatable/equatable.dart';
import 'package:flap_app/models/friend_request.dart';

abstract class FriendsEvent extends Equatable {
  const FriendsEvent();

  @override
  List<Object?> get props => [];
}

class FriendsStarted extends FriendsEvent {
  const FriendsStarted();
}

class FriendsIncomingUpdated extends FriendsEvent {
  const FriendsIncomingUpdated(this.requests);

  final List<FriendRequest> requests;

  @override
  List<Object?> get props => [requests];
}

class FriendsOutgoingUpdated extends FriendsEvent {
  const FriendsOutgoingUpdated(this.requests);

  final List<FriendRequest> requests;

  @override
  List<Object?> get props => [requests];
}

class FriendsLoadFriendsRequested extends FriendsEvent {
  const FriendsLoadFriendsRequested();
}

class FriendsSearchRequested extends FriendsEvent {
  const FriendsSearchRequested(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class FriendsSendFriendRequest extends FriendsEvent {
  const FriendsSendFriendRequest(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

class FriendsRespondToRequest extends FriendsEvent {
  const FriendsRespondToRequest(this.requestId, this.accept);

  final String requestId;
  final bool accept;

  @override
  List<Object?> get props => [requestId, accept];
}

class FriendsCancelRequest extends FriendsEvent {
  const FriendsCancelRequest(this.requestId);

  final String requestId;

  @override
  List<Object?> get props => [requestId];
}

class FriendsRemoveFriend extends FriendsEvent {
  const FriendsRemoveFriend({required this.friendUserId, required this.friendName});

  final String friendUserId;
  final String friendName;

  @override
  List<Object?> get props => [friendUserId, friendName];
}

class FriendsClearMessages extends FriendsEvent {
  const FriendsClearMessages();
}
