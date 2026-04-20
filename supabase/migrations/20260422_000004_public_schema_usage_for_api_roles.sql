-- PostgREST connects as roles `anon` / `authenticated` (JWT) / `service_role`.
-- Without USAGE on schema public, the API returns:
--   PostgrestException: permission denied for schema public (42501)
-- This can appear after a partial restore, manual role changes, or non-standard DB setup.
-- Runtime can also fail with table-level permissions like:
--   PostgrestException: permission denied for table profiles (42501)
-- Safe to re-run (idempotent grants).

grant usage on schema public to anon, authenticated, service_role;

-- Let API roles access existing objects in public.
-- RLS policies still control row-level access.
grant select, insert, update, delete on all tables in schema public
  to anon, authenticated, service_role;
grant usage, select on all sequences in schema public
  to anon, authenticated, service_role;
grant execute on all functions in schema public
  to anon, authenticated, service_role;

-- Ensure future objects in public receive the same privileges.
alter default privileges in schema public
  grant select, insert, update, delete on tables
  to anon, authenticated, service_role;
alter default privileges in schema public
  grant usage, select on sequences
  to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions
  to anon, authenticated, service_role;
