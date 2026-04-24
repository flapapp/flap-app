import 'dart:async';

/// Fired after the current user's profile document was saved on the server so
/// UI that caches [UserProfile] / `profileDocument` maps can refetch.
final class ProfileUserDataSync {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get onUpdated => _controller.stream;

  void notifyUpdated() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
