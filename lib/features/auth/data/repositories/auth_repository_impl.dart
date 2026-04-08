import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final SupabaseAuthDataSource _dataSource;

  @override
  AppUser? get currentUser => _dataSource.currentUser;

  @override
  Stream<AppUser?> get authStateChanges => _dataSource.authStateChanges;

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _dataSource.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<AppUser> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      _dataSource.signUpWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
  Future<void> setWebPersistenceLocal() => _dataSource.setWebPersistenceLocal();
}
