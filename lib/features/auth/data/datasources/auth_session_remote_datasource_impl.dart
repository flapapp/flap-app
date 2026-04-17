import 'package:firebase_auth/firebase_auth.dart';

import 'auth_session_remote_datasource.dart';

class AuthSessionRemoteDataSourceImpl implements AuthSessionRemoteDataSource {
  AuthSessionRemoteDataSourceImpl();

  @override
  String? get currentUserIdOrNull {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> resolveInitialUserId() async {
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 2), onTimeout: () => null);
        } catch (_) {
          user = FirebaseAuth.instance.currentUser;
        }
      }
      return user?.uid;
    } catch (_) {
      return null;
    }
  }
}
