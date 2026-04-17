import '../../../../core/error/result.dart';
import '../entities/auth_user.dart';
import '../entities/register_request.dart';

/// Email/password auth and full registration (domain contract).
abstract class AuthRepository {
  Future<Result<AuthUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Creates Firebase account, optional avatar upload, and Firestore profile.
  Future<Result<AuthUser>> registerNewUser(RegisterRequest request);
}
