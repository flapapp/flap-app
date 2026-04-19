import 'package:supabase_flutter/supabase_flutter.dart';

/// Session helpers backed by Supabase Auth (UUID user ids aligned with `profiles.id`).
abstract final class AppAuth {
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static String? get currentUserEmail => currentUser?.email;

  static Stream<AuthState> get onAuthStateChange =>
      Supabase.instance.client.auth.onAuthStateChange;

  static Future<void> signOut() => Supabase.instance.client.auth.signOut();
}
