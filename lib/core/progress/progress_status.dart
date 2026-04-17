/// Shared async lifecycle for operations across feature modules (BLoC state).
enum ProgressStatus {
  /// Idle / not started.
  pure,

  /// Work in flight.
  loading,

  /// Completed with an error (see paired [Failure] or message on state).
  failure,

  /// Completed successfully (see paired data on state).
  success,
}
