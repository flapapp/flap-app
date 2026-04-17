import 'no_params.dart';

/// Base contract for application-specific business rules.
abstract class UseCase<TOutput, Params> {
  Future<TOutput> call(Params params);
}

/// Use case with no input.
abstract class UseCaseNoParams<TOutput> {
  Future<TOutput> call([NoParams params = const NoParams()]);
}
