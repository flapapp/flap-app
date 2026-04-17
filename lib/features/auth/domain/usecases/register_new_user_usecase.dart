import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/auth_user.dart';
import '../entities/register_request.dart';
import '../repositories/auth_repository.dart';

class RegisterNewUserUseCase implements UseCase<Result<AuthUser>, RegisterRequest> {
  RegisterNewUserUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthUser>> call(RegisterRequest params) {
    return _repository.registerNewUser(params);
  }
}
