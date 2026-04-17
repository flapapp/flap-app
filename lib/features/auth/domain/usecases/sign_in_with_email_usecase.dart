import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInParams {
  const SignInParams({required this.email, required this.password});

  final String email;
  final String password;
}

class SignInWithEmailUseCase implements UseCase<Result<AuthUser>, SignInParams> {
  SignInWithEmailUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthUser>> call(SignInParams params) {
    return _repository.signInWithEmailAndPassword(
      email: params.email,
      password: params.password,
    );
  }
}
