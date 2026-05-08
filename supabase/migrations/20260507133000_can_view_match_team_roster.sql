-- Team roster players were excluded from can_view_match() for private matches because
-- visibility only checked organizer / match_participants / match_invites.
-- That blocked SELECT on matches, match_teams, and match_team_rosters for roster-only
-- members, so "My Matches" could not load their team matches end-to-end.

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
        or exists (
          select 1 from public.match_team_rosters mtr
          join public.match_teams mt on mt.id = mtr.match_team_id
          where mt.match_id = m.id
            and mtr.player_id = p_viewer
            and mtr.status <> 'declined'
        )
      )
  );
$$;
