import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.cache() = FailureCache;

  const factory Failure.network([String? message]) = FailureNetwork;

  const factory Failure.unexpected([String? message]) = FailureUnexpected;

  /// Firebase Auth / credential failures — map [code] to user-facing copy in UI.
  const factory Failure.auth({
    required String code,
    String? message,
  }) = FailureAuth;
}
