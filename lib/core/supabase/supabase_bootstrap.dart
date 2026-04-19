import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

/// Loads [SupabaseEnv] from `--dart-define=SUPABASE_URL=...` and
/// `--dart-define=SUPABASE_ANON_KEY=...`, then initializes the client.
///
/// If either value is missing, initialization is skipped (Supabase-backed
/// code should guard with [SupabaseEnv] or [Supabase.instance] usage).
Future<void> initializeSupabase() async {
  if (SupabaseEnv.url.isEmpty || SupabaseEnv.anonKey.isEmpty) {
    if (kDebugMode) {
      debugPrint(
        'Supabase: not initialized (set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define).',
      );
    }
    return;
  }

  await Supabase.initialize(
    url: SupabaseEnv.url,
    anonKey: SupabaseEnv.anonKey,
    debug: kDebugMode,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}
