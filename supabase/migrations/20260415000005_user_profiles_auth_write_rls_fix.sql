begin;

-- Ensure table grants are present for PostgREST role.
grant select, insert, update, delete on table public.user_profiles to authenticated;
grant select on table public.user_profiles to anon;

alter table public.user_profiles enable row level security;

drop policy if exists "profiles are publicly readable if not soft-deleted" on public.user_profiles;
drop policy if exists "users can insert their own profile" on public.user_profiles;
drop policy if exists "users can update their own profile" on public.user_profiles;

create policy "profiles are publicly readable if not soft-deleted"
on public.user_profiles
for select
using (deleted_at is null);

create policy "users can insert their own profile"
on public.user_profiles
for insert
to authenticated
with check (auth.uid() = id);

create policy "users can update their own profile"
on public.user_profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

commit;
