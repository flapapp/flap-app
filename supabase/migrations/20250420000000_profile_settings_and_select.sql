-- App settings previously stored under Firestore `users.settings`.
alter table public.profiles
  add column if not exists settings jsonb not null default '{}'::jsonb;

-- Friend lists, player profiles, and leaderboards read other users' rows via the
-- anon/authenticated client. Allow any signed-in user to read profiles (same as
-- typical public player cards). Email/phone remain in row; tighten columns later if needed.
drop policy if exists "Users read own profile" on public.profiles;

-- Logged-in clients use the `authenticated` role; they can read any profile row for
-- social features (same broad read model as legacy Firestore `users` docs).
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

-- Realtime stream used by the Flutter client for live profile updates.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
exception
  when duplicate_object then null;
end $$;
