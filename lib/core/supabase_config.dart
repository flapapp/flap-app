/// Supabase client bootstrap via compile-time defines:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
class SupabaseConfig {
  SupabaseConfig._();

  // static const String url = String.fromEnvironment('SUPABASE_URL');
  // static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String url = 'https://lqsbqtxioxxwdhsdophf.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxxc2JxdHhpb3h4d2Roc2RvcGhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxMjYyNzMsImV4cCI6MjA5MTcwMjI3M30.IMSIkLt_p3a1Hc-4ssuCOVxe2V25MfQDmmKxhRmK0MM';

  static void assertConfigured() {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Set SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define when running the app.',
      );
    }
  }
}
