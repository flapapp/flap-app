import 'package:freezed_annotation/freezed_annotation.dart';

import 'failure.dart';

part 'result.freezed.dart';

@Freezed(genericArgumentFactories: true)
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = ResultSuccess;

  const factory Result.failure(Failure failure) = ResultFailure;
}
