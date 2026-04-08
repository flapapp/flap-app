# User import and ID mapping

Supabase issues a new UUID per account. If you import users from another system, keep a **separate mapping** (e.g. CSV or table) from old user ids to new Supabase `user.id` values, and use that when rewriting foreign keys in your data migration.

## Passwords

Password hashes from another provider usually cannot be imported. Typical approaches:

1. Send users a password-reset or magic-link flow so they set a new password in Supabase.
2. Implement a one-time server-side session exchange (custom backend or Edge Function) if you need a smoother transition.

## Suggested flow

1. Export users from the legacy system (email list + stable legacy ids).
2. Create users with the Supabase Admin API (`email_confirm` as appropriate).
3. Record each pair `legacy_id,supabase_user_id` for use in database/document migration scripts.
