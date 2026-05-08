-- Atomic team-match creation RPC.
--
-- Why: the previous client-side flow inserted the matches row first, then
-- separately inserted into team_match_requests. RLS could reject the second
-- insert (e.g. when the organizer is not a captain of the requesting team)
-- and there was no rollback for the matches row. Users then re-tapped
-- "Create" and accumulated 2-4 orphan matches per attempt:
--
--   ❌  Create  ─►  matches✓  ─►  team_match_requests❌ (RLS 42501)
--   ❌  Create  ─►  matches✓  ─►  team_match_requests❌
--   ❌  Create  ─►  matches✓  ─►  team_match_requests❌
--
-- This migration introduces `create_team_match` as a SECURITY DEFINER RPC
-- that performs every required write in a single transaction. The RPC
-- enforces its own authorization (organizer is auth.uid()), and either every
-- row commits or none does — so RLS misalignments and partial failures can
-- no longer leak orphan matches.

create or replace function public.create_team_match(
  p_title text,
  p_description text,
  p_scheduled_at timestamptz,
  p_location text,
  p_city text,
  p_latitude double precision,
  p_longitude double precision,
  p_max_players int,
  p_participation_cost numeric,
  p_level text,
  p_is_private boolean,
  p_host_team_id uuid,
  p_host_roster uuid[] default null,
  p_opponent_team_id uuid default null,
  p_opponent_proposed_roster uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match_id uuid;
  v_host_match_team_id uuid;
  v_host_member boolean := false;
  v_request_id uuid := null;
  v_player uuid;
  v_host_name text;
  v_level text;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if p_title is null or btrim(p_title) = '' then
    raise exception 'Match title is required';
  end if;

  if p_max_players is null or p_max_players <= 0 then
    raise exception 'max_players must be > 0';
  end if;

  if p_host_team_id is null then
    raise exception 'A host team is required for team matches';
  end if;

  -- Sanity: host team must exist (RLS is bypassed because we are SECURITY
  -- DEFINER, so check explicitly).
  select coalesce(name, 'Team') into v_host_name
  from public.teams where id = p_host_team_id;
  if v_host_name is null then
    raise exception 'Host team not found';
  end if;

  -- Optional opponent team must exist as well.
  if p_opponent_team_id is not null then
    if not exists (select 1 from public.teams where id = p_opponent_team_id) then
      raise exception 'Opponent team not found';
    end if;
    if p_opponent_team_id = p_host_team_id then
      raise exception 'Opponent team must differ from host team';
    end if;
  end if;

  -- Is the caller a member of the host team? Used to decide whether the host
  -- roster they pass through is auto-confirmed (member-organizer) or simply
  -- recorded as a pending suggestion (non-member organizer).
  select exists (
    select 1 from public.team_members
    where team_id = p_host_team_id and user_id = v_uid
  ) into v_host_member;

  -- Validate level against the matches.level CHECK constraint to surface
  -- friendlier errors than the underlying constraint failure.
  v_level := nullif(p_level, '');
  if v_level is not null and v_level not in ('beginner','intermediate','advanced','pro') then
    raise exception 'Invalid level: %', v_level;
  end if;

  -- 1. matches row
  insert into public.matches (
    organizer_id, title, description, scheduled_at,
    location, city, latitude, longitude,
    max_players, participation_cost, level,
    auto_balance, is_private, is_team_match, status
  ) values (
    v_uid, p_title, p_description, p_scheduled_at,
    p_location, p_city, p_latitude, p_longitude,
    p_max_players, coalesce(p_participation_cost, 0), v_level,
    false, coalesce(p_is_private, false), true, 'open'
  )
  returning id into v_match_id;

  -- 2. organizer becomes a participant (parity with non-team match flow)
  insert into public.match_participants (
    match_id, user_id, status, joined_at, responded_at
  ) values (
    v_match_id, v_uid, 'accepted', now(), now()
  )
  on conflict (match_id, user_id) do nothing;

  -- 3. host slot 1 match_team
  insert into public.match_teams (
    match_id, team_slot, source_team_id, display_name
  ) values (
    v_match_id, 1, p_host_team_id, v_host_name
  )
  returning id into v_host_match_team_id;

  -- 4. host roster (only if the organizer is a team member; non-member
  -- organizers cannot pre-confirm anyone — captains will accept later).
  if v_host_member
     and p_host_roster is not null
     and array_length(p_host_roster, 1) is not null
     and array_length(p_host_roster, 1) > 0 then
    foreach v_player in array p_host_roster loop
      -- Restrict to actual host team members so callers cannot stuff
      -- arbitrary user ids into the roster via the RPC.
      if exists (
        select 1 from public.team_members
        where team_id = p_host_team_id and user_id = v_player
      ) then
        insert into public.match_team_rosters (
          match_team_id, player_id, status, updated_at
        ) values (
          v_host_match_team_id, v_player, 'confirmed', now()
        )
        on conflict (match_team_id, player_id) do update
          set status = 'confirmed', updated_at = now();
      end if;
    end loop;
  end if;

  -- 5. team_match_requests row + optional proposed opponent roster.
  -- This is the step that previously failed RLS for non-officer organizers.
  if p_opponent_team_id is not null then
    insert into public.team_match_requests (
      match_id, requesting_team_id, target_team_id, created_by, status
    ) values (
      v_match_id, p_host_team_id, p_opponent_team_id, v_uid, 'pending'
    )
    returning id into v_request_id;

    if p_opponent_proposed_roster is not null
       and array_length(p_opponent_proposed_roster, 1) is not null
       and array_length(p_opponent_proposed_roster, 1) > 0 then
      foreach v_player in array p_opponent_proposed_roster loop
        if exists (
          select 1 from public.team_members
          where team_id = p_opponent_team_id and user_id = v_player
        ) then
          insert into public.team_match_request_players (
            team_match_request_id, player_id
          ) values (
            v_request_id, v_player
          )
          on conflict do nothing;
        end if;
      end loop;
    end if;
  end if;

  -- The trigger from 20260508120000 will materialise the slot-2 match_teams
  -- placeholder (host slot 1 already exists above), and the team_stats
  -- aggregation triggers from 20260508140000 will pick this match up the
  -- moment it finishes.

  return jsonb_build_object(
    'success', true,
    'matchId', v_match_id,
    'matchTeamA', v_host_match_team_id,
    'requestId', v_request_id
  );
end;
$$;

grant execute on function public.create_team_match(
  text, text, timestamptz, text, text,
  double precision, double precision,
  int, numeric, text, boolean,
  uuid, uuid[], uuid, uuid[]
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Cleanup utility for orphan team matches that pre-date the atomic RPC.
-- A match is considered an orphan if it is `is_team_match=true`, status='open',
-- has no roster on slot 2 yet, and has no pending team_match_requests row.
-- This typically means the historical multi-step flow committed `matches`
-- but failed before the team_match_requests insert.
-- ---------------------------------------------------------------------------

create or replace function public.cleanup_orphan_team_matches()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int := 0;
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'Admin required';
  end if;

  with deletable as (
    select m.id
    from public.matches m
    where m.is_team_match is true
      and m.status = 'open'
      and not exists (
        select 1 from public.team_match_requests tmr
        where tmr.match_id = m.id
      )
      and not exists (
        select 1 from public.match_team_rosters mtr
        join public.match_teams mt on mt.id = mtr.match_team_id
        where mt.match_id = m.id and mt.team_slot = 2
      )
  )
  delete from public.matches m
  using deletable d
  where m.id = d.id;
  get diagnostics v_count = row_count;

  return jsonb_build_object('success', true, 'deleted', v_count);
end;
$$;

grant execute on function public.cleanup_orphan_team_matches()
  to authenticated, service_role;
