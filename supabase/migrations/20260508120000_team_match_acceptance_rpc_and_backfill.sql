-- Team-match acceptance lifecycle was incomplete: clients only updated
-- team_match_requests.status='accepted' without populating match_teams (slot 2)
-- or match_team_rosters for the invited team. As a result:
--   * Invited-team players were NOT visible to the match (visibility helpers
--     scan match_team_rosters joined to match_teams).
--   * "My Matches" never listed the match for invited-team players.
--   * Player & team stat aggregation never saw participation rows so finished
--     team matches did not affect win/loss/recent results/goals.
--
-- This migration introduces SECURITY DEFINER RPCs that perform the full
-- propagation transactionally and idempotently, plus a one-time backfill so
-- existing accepted team matches start exposing their invited teams.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Visibility extension: team officers see matches their team is involved in
-- ---------------------------------------------------------------------------
-- A captain who excludes themselves from the confirmed roster (e.g. coach,
-- bench) would otherwise lose visibility on the match they manage. Allow team
-- officers of any team referenced by team_match_requests on the match.
--
-- This helper is defined SECURITY DEFINER + row_security off so it does not
-- recurse through the team_match_requests SELECT policy.

create or replace function public.user_is_match_team_officer(
  p_match_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select exists (
    select 1
    from public.team_match_requests tmr
    join public.team_members tm
      on tm.user_id = p_user_id
     and tm.role in ('captain', 'vice_captain')
     and tm.team_id in (tmr.requesting_team_id, tmr.target_team_id)
    where tmr.match_id = p_match_id
  );
$$;

grant execute on function public.user_is_match_team_officer(uuid, uuid)
  to authenticated, service_role;

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
        or public.user_is_match_team_officer(m.id, p_viewer)
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public._effective_team_match_roster(
  p_request_id uuid,
  p_target_team_id uuid,
  p_explicit uuid[]
)
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_proposed uuid[];
  v_members uuid[];
  v_explicit uuid[] := coalesce(p_explicit, array[]::uuid[]);
begin
  if array_length(v_explicit, 1) is not null and array_length(v_explicit, 1) > 0 then
    -- Restrict explicit roster to actual team members to prevent stuffing
    -- arbitrary user ids via the RPC.
    return array(
      select tm.user_id
      from public.team_members tm
      where tm.team_id = p_target_team_id
        and tm.user_id = any(v_explicit)
    );
  end if;

  select array_agg(distinct tmrp.player_id)
  into v_proposed
  from public.team_match_request_players tmrp
  join public.team_members tm
    on tm.user_id = tmrp.player_id
   and tm.team_id = p_target_team_id
  where tmrp.team_match_request_id = p_request_id;

  if v_proposed is not null and array_length(v_proposed, 1) > 0 then
    return v_proposed;
  end if;

  select array_agg(distinct tm.user_id)
  into v_members
  from public.team_members tm
  where tm.team_id = p_target_team_id;

  return coalesce(v_members, array[]::uuid[]);
end;
$$;

grant execute on function public._effective_team_match_roster(uuid, uuid, uuid[])
  to authenticated, service_role;

create or replace function public._upsert_match_team_for_source(
  p_match_id uuid,
  p_team_slot int,
  p_source_team_id uuid,
  p_display_name text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_team_id uuid;
  v_total_rating double precision;
begin
  -- Prefer reuse of an existing row keyed by source_team_id (a previous client
  -- path may have written it without `source_team_id`, or with a mismatched
  -- slot). This sidesteps the unique (match_id, team_slot) constraint when
  -- the same team needs to migrate slots.
  select id
  into v_match_team_id
  from public.match_teams
  where match_id = p_match_id
    and source_team_id = p_source_team_id
  limit 1;

  if v_match_team_id is not null then
    update public.match_teams
    set
      team_slot = p_team_slot,
      display_name = case
        when display_name is null or btrim(display_name) = '' then p_display_name
        else display_name
      end
    where id = v_match_team_id;
  else
    -- Atomic upsert keyed by (match_id, team_slot).
    insert into public.match_teams(
      match_id, team_slot, source_team_id, display_name
    )
    values (p_match_id, p_team_slot, p_source_team_id, p_display_name)
    on conflict (match_id, team_slot) do update
      set source_team_id = coalesce(public.match_teams.source_team_id, excluded.source_team_id),
          display_name = case
            when public.match_teams.display_name is null
              or btrim(public.match_teams.display_name) = ''
              then excluded.display_name
            else public.match_teams.display_name
          end
    returning id into v_match_team_id;
  end if;

  -- Recompute team_total_rating from confirmed roster snapshot.
  select coalesce(sum(coalesce(p.overall_rating, 0)), 0)::double precision
  into v_total_rating
  from public.match_team_rosters mtr
  left join public.profiles p on p.id = mtr.player_id
  where mtr.match_team_id = v_match_team_id
    and mtr.status <> 'declined';

  update public.match_teams
  set team_total_rating = v_total_rating
  where id = v_match_team_id;

  return v_match_team_id;
end;
$$;

grant execute on function public._upsert_match_team_for_source(uuid, int, uuid, text)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Accept / decline / cancel RPCs
-- ---------------------------------------------------------------------------

create or replace function public.accept_team_match_request(
  p_request_id uuid,
  p_roster uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.team_match_requests%rowtype;
  v_match public.matches%rowtype;
  v_target_name text;
  v_host_name text;
  v_match_team_b uuid;
  v_match_team_a uuid;
  v_roster uuid[];
  v_player uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.team_match_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Team match request not found';
  end if;

  -- Caller must be captain or vice_captain of the invited team.
  if not public.is_team_officer(v_req.target_team_id, v_uid) then
    raise exception 'Only invited team captains can accept this match request';
  end if;

  if v_req.status not in ('pending', 'accepted') then
    raise exception 'Team match request is no longer pending';
  end if;

  select * into v_match
  from public.matches
  where id = v_req.match_id;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_match.status not in ('open', 'full') then
    raise exception 'Match is no longer accepting team responses';
  end if;

  select coalesce(name, 'Team') into v_target_name
  from public.teams where id = v_req.target_team_id;

  select coalesce(name, 'Team') into v_host_name
  from public.teams where id = v_req.requesting_team_id;

  -- Ensure host (slot 1) match_team row exists with source_team_id set so that
  -- downstream readers (legacy mapper / analytics) can resolve teamAId.
  v_match_team_a := public._upsert_match_team_for_source(
    v_req.match_id,
    1,
    v_req.requesting_team_id,
    v_host_name
  );

  -- Ensure invited (slot 2) match_team row exists.
  v_match_team_b := public._upsert_match_team_for_source(
    v_req.match_id,
    2,
    v_req.target_team_id,
    v_target_name
  );

  -- Resolve the effective roster (explicit > proposed > full team).
  v_roster := public._effective_team_match_roster(
    p_request_id,
    v_req.target_team_id,
    p_roster
  );

  if array_length(v_roster, 1) is null or array_length(v_roster, 1) = 0 then
    raise exception 'Cannot accept team match: invited team has no eligible members';
  end if;

  -- Idempotent roster sync for the invited team.
  -- Mark anyone removed from the new roster as 'declined' rather than deleting
  -- so notification history (and potential ratings) survive churn.
  update public.match_team_rosters
  set status = 'declined',
      updated_at = now()
  where match_team_id = v_match_team_b
    and player_id <> all(v_roster)
    and status <> 'declined';

  foreach v_player in array v_roster loop
    insert into public.match_team_rosters(match_team_id, player_id, status, updated_at)
    values (v_match_team_b, v_player, 'confirmed', now())
    on conflict (match_team_id, player_id) do update
      set status = 'confirmed',
          updated_at = now();
  end loop;

  -- Recompute team total rating now that rosters are confirmed.
  perform public._upsert_match_team_for_source(
    v_req.match_id,
    2,
    v_req.target_team_id,
    v_target_name
  );

  -- Mark request accepted (idempotent) and decline any other pending invites
  -- for this match - only one opponent slot per team match.
  update public.team_match_requests
  set status = 'accepted',
      responded_at = now()
  where id = v_req.id;

  update public.team_match_requests
  set status = 'declined',
      responded_at = coalesce(responded_at, now())
  where match_id = v_req.match_id
    and id <> v_req.id
    and status = 'pending';

  return jsonb_build_object(
    'success', true,
    'matchId', v_req.match_id,
    'matchTeamA', v_match_team_a,
    'matchTeamB', v_match_team_b,
    'rosterSize', coalesce(array_length(v_roster, 1), 0)
  );
end;
$$;

grant execute on function public.accept_team_match_request(uuid, uuid[])
  to authenticated, service_role;

create or replace function public.decline_team_match_request(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.team_match_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.team_match_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Team match request not found';
  end if;

  -- Caller must be captain/vice of invited team.
  if not public.is_team_officer(v_req.target_team_id, v_uid) then
    raise exception 'Only invited team captains can decline this match request';
  end if;

  if v_req.status not in ('pending', 'accepted') then
    return jsonb_build_object('success', true, 'status', v_req.status);
  end if;

  update public.team_match_requests
  set status = 'declined',
      responded_at = now()
  where id = v_req.id;

  -- If invited team had been confirmed previously (accept then later decline),
  -- mark their roster rows declined so they leave 'My Matches' and stop
  -- contributing to stats.
  update public.match_team_rosters mtr
  set status = 'declined',
      updated_at = now()
  from public.match_teams mt
  where mtr.match_team_id = mt.id
    and mt.match_id = v_req.match_id
    and mt.source_team_id = v_req.target_team_id
    and mtr.status <> 'declined';

  return jsonb_build_object('success', true, 'status', 'declined');
end;
$$;

grant execute on function public.decline_team_match_request(uuid)
  to authenticated, service_role;

create or replace function public.cancel_team_match_request(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.team_match_requests%rowtype;
  v_organizer_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.team_match_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Team match request not found';
  end if;

  select organizer_id into v_organizer_id
  from public.matches where id = v_req.match_id;

  -- Only requesting-team officers or the match organizer can cancel.
  if not (
    public.is_team_officer(v_req.requesting_team_id, v_uid)
    or v_organizer_id = v_uid
    or public.is_admin()
  ) then
    raise exception 'Only the requesting team or match organizer can cancel this request';
  end if;

  update public.team_match_requests
  set status = 'cancelled',
      responded_at = now()
  where id = v_req.id;

  return jsonb_build_object('success', true, 'status', 'cancelled');
end;
$$;

grant execute on function public.cancel_team_match_request(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- One-time backfill for past accepted team matches that pre-date the RPC
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
  v_match_team_id uuid;
  v_player uuid;
  v_roster uuid[];
  v_host_name text;
  v_target_name text;
begin
  for r in
    select tmr.id as request_id,
           tmr.match_id,
           tmr.requesting_team_id,
           tmr.target_team_id
    from public.team_match_requests tmr
    join public.matches m on m.id = tmr.match_id
    where tmr.status = 'accepted'
      and m.is_team_match is true
  loop
    select coalesce(name, 'Team') into v_host_name
    from public.teams where id = r.requesting_team_id;

    select coalesce(name, 'Team') into v_target_name
    from public.teams where id = r.target_team_id;

    -- Slot 1
    perform public._upsert_match_team_for_source(
      r.match_id, 1, r.requesting_team_id, v_host_name
    );

    -- Slot 2
    v_match_team_id := public._upsert_match_team_for_source(
      r.match_id, 2, r.target_team_id, v_target_name
    );

    -- Backfill roster only when team B currently has zero non-declined rows.
    if not exists (
      select 1
      from public.match_team_rosters mtr
      where mtr.match_team_id = v_match_team_id
        and mtr.status <> 'declined'
    ) then
      v_roster := public._effective_team_match_roster(
        r.request_id, r.target_team_id, null
      );

      if array_length(v_roster, 1) is not null and array_length(v_roster, 1) > 0 then
        foreach v_player in array v_roster loop
          insert into public.match_team_rosters(match_team_id, player_id, status)
          values (v_match_team_id, v_player, 'confirmed')
          on conflict (match_team_id, player_id) do nothing;
        end loop;
      end if;
    end if;

    perform public._upsert_match_team_for_source(
      r.match_id, 2, r.target_team_id, v_target_name
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Forward backfill: ensure new team matches always have a slot-2 placeholder.
-- The Flutter create flow does this too, but the trigger keeps the data model
-- consistent for existing Supabase consumers / direct API callers.
-- ---------------------------------------------------------------------------

create or replace function public.ensure_team_match_slot_two_on_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_name text;
  v_host_name text;
begin
  if new.status not in ('pending', 'accepted') then
    return new;
  end if;

  select coalesce(name, 'Team') into v_host_name
  from public.teams where id = new.requesting_team_id;

  select coalesce(name, 'Team') into v_target_name
  from public.teams where id = new.target_team_id;

  perform public._upsert_match_team_for_source(
    new.match_id, 1, new.requesting_team_id, v_host_name
  );
  perform public._upsert_match_team_for_source(
    new.match_id, 2, new.target_team_id, v_target_name
  );
  return new;
end;
$$;

drop trigger if exists trg_ensure_team_match_slot_two
  on public.team_match_requests;
create trigger trg_ensure_team_match_slot_two
after insert on public.team_match_requests
for each row execute function public.ensure_team_match_slot_two_on_request_insert();
