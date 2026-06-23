import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/injection.dart';
import '../interactions/interaction_store.dart';
import '../interactions/user_rating_store.dart';

/// Session helpers backed by Supabase Auth (UUID user ids aligned with `profiles.id`).
abstract final class AppAuth {
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static String? get currentUserEmail => currentUser?.email;

  static Stream<AuthState> get onAuthStateChange =>
      Supabase.instance.client.auth.onAuthStateChange;

  static Future<void> signOut() async {
    // Drop cached per-user interaction state so liked/voted flags don't leak
    // into the next session.
    if (sl.isRegistered<InteractionStore>()) sl<InteractionStore>().clear();
    if (sl.isRegistered<UserRatingStore>()) sl<UserRatingStore>().clear();
    await Supabase.instance.client.auth.signOut();
  }
}
