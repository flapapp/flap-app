-- Roster-only visibility failed because can_view_match was extended with an EXISTS that
-- JOINs match_teams. The match_teams SELECT policy calls can_view_match → recursion /
-- failed checks, so roster players never saw private team matches.
--
-- Narrow helper: SECURITY DEFINER + SET row_security = off for this query only (restored
-- when the function exits per PostgreSQL function SET semantics).

create or replace function public.user_participates_via_team_roster(p_match_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.match_team_rosters mtr
    join public.match_teams mt on mt.id = mtr.match_team_id
    where mt.match_id = p_match_id
      and mtr.player_id = p_user_id
      and mtr.status <> 'declined'
  );
$$;

grant execute on function public.user_participates_via_team_roster(uuid, uuid) to authenticated;

create or replace function public.can_view_match(p_match_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and (
        not m.is_private
        or m.organizer_id = p_viewer
        or exists (
          select 1 from public.match_participants mp
          where mp.match_id = m.id and mp.user_id = p_viewer
        )
        or exists (
          select 1 from public.match_invites mi
          where mi.match_id = m.id and mi.user_id = p_viewer
        )
        or public.user_participates_via_team_roster(m.id, p_viewer)
      )
  );
$$;

-- Allow reading own roster rows without depending on can_view_match first (direct API +
-- nested embeds).
create policy match_team_rosters_select_own_player_row
  on public.match_team_rosters for select
  to authenticated
  using (player_id = (select auth.uid()));
