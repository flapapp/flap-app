import 'dart:async';

/// Broadcasts when video library data may have changed (upload/delete from any route).
/// [VideoMainScreen] listens and clears memoized feed futures so lists stay fresh.
final class VideoFeedSync {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get onMutated => _controller.stream;

  void notifyFeedMayHaveChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
