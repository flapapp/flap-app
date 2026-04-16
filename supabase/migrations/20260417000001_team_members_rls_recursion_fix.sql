-- Fix PostgrestException 42P17: infinite recursion in policy for relation "team_members".
-- Policies on `teams` and `team_members` queried `team_members` again, re-entering RLS.
-- SECURITY DEFINER helpers read membership with the privileges of the function owner (bypass RLS).

create or replace function public.is_team_member(_team_id uuid, _user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = _team_id
      and tm.user_id = _user_id
  );
$$;

create or replace function public.is_team_admin_or_owner(_team_id uuid, _user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = _team_id
      and tm.user_id = _user_id
      and tm.role in ('OWNER', 'ADMIN')
  );
$$;

grant execute on function public.is_team_member(uuid, uuid) to authenticated;
grant execute on function public.is_team_admin_or_owner(uuid, uuid) to authenticated;

-- teams: stop querying team_members directly from RLS
drop policy if exists "public teams are visible; private teams visible to members" on public.teams;

create policy "public teams are visible; private teams visible to members"
on public.teams
for select
using (
  deleted_at is null
  and (
    is_public = true
    or owner_id = auth.uid()
    or public.is_team_member(id, auth.uid())
  )
);

-- team_members: stop self-referential subquery on team_members
drop policy if exists "team members are visible to authorized team viewers" on public.team_members;

create policy "team members are visible to authorized team viewers"
on public.team_members
for select
using (
  exists (
    select 1
    from public.teams t
    where t.id = team_id
      and t.deleted_at is null
      and (
        t.is_public = true
        or t.owner_id = auth.uid()
        or public.is_team_member(team_id, auth.uid())
      )
  )
);
