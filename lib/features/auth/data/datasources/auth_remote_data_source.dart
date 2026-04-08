import '../../domain/entities/app_user.dart';

abstract class AuthRemoteDataSource {
  AppUser? get currentUser;

  Stream<AppUser?> get authStateChanges;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> setWebPersistenceLocal();
}
