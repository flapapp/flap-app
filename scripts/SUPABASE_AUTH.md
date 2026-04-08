# Supabase authentication (app)

The Flutter client expects these compile-time defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Apply SQL in `supabase/migrations/` to your project before relying on sign-up (profiles table + trigger).

For web push, optional: `--dart-define=WEB_PUSH_VAPID_KEY=...` (VAPID public key for the messaging plugin).
