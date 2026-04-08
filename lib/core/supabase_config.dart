/// Supabase client bootstrap via compile-time defines:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class SupabaseConfig {
  SupabaseConfig._();

  // static const String url = String.fromEnvironment('SUPABASE_URL');
  // static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String url = 'https://uaftylfyqzvhjlgddrey.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZnR5bGZ5cXp2aGpsZ2RkcmV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2ODkzNzcsImV4cCI6MjA5MTI2NTM3N30.G97_t-wNefKhqAOHEklwz3_2PrGwVpL5w4vxrgNMTK0';

  static void assertConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define when running the app.',
      );
    }
  }
}
