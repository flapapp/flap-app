-- Fix PostgrestException 42501: new row violates row-level security policy for table "team_members".
--
-- The INSERT policy required public.is_team_admin_or_owner(team_id, auth.uid()), which reads
-- team_members. After creating a team, trigger create_team_owner_membership() inserts the
-- first OWNER row — but no membership row exists yet, so the check fails (bootstrap deadlock).
--
-- Also, apply_team_membership_acceptance() inserts the invitee as PLAYER when a membership is
-- ACCEPTED; the invitee is not yet in team_members, so the old policy blocked that too.
--
-- Allow INSERT when:
-- 1) Existing admin/owner in team_members (unchanged), or
-- 2) Caller owns the team in public.teams (bootstrap + owner-managed roster), or
-- 3) A matching ACCEPTED team_memberships row exists for this (team_id, user_id) pair.

drop policy if exists "team owner admin can manage members" on public.team_members;

create policy "team owner admin can manage members"
on public.team_members
for insert
with check (
  public.is_team_admin_or_owner(team_id, auth.uid())
  or exists (
    select 1
    from public.teams t
    where t.id = team_id
      and t.deleted_at is null
      and t.owner_id = auth.uid()
  )
  or (
    auth.uid() = user_id
    and exists (
      select 1
      from public.team_memberships m
      where m.team_id = team_id
        and m.user_id = user_id
        and m.status = 'ACCEPTED'::public.team_membership_status
    )
  )
);
