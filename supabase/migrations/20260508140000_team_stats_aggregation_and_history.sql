-- Team-stat propagation for finished team matches.
--
-- Pre-fix state: there was no `team_stats` table at all. The Flutter
-- `TeamStatsRemoteDataSource` and `watchTeamStatsCollection` literally returned
-- zeros for every team. As a result no W/L/D/GF/GA/streak/recent-form data
-- ever surfaced after a team match finished.
--
-- This migration introduces:
--   * `team_match_history`  : append-only journal of finished team-vs-team
--     matches, two rows per match (one per team).
--   * `team_stats`          : aggregate row per team (counters + recent form +
--     recent matches snapshot + per-player goals for that team).
--   * Helpers + triggers that keep `team_stats` perfectly in sync with finished
--     matches, idempotent against replayed finalisation, admin edits and
--     cancel/uncancel cycles.
--   * Public RPCs `recompute_team_stats` / `recompute_all_team_stats` /
--     `rebuild_team_match_history` for repair & verification flows.
--   * One-time backfill that walks every existing finished team match.
--
-- Constraints:
--   * Casual / non-team matches are explicitly skipped.
--   * Cancelled matches do NOT count and any prior history rows are removed.
--   * All writes go through `INSERT ... ON CONFLICT DO UPDATE`, all
--     recomputations are derived from the journal, so duplicates / replays
--     converge to the same value.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.team_match_history (
  team_id                 uuid not null references public.teams(id) on delete cascade,
  match_id                uuid not null references public.matches(id) on delete cascade,
  match_team_id           uuid not null references public.match_teams(id) on delete cascade,
  opponent_team_id        uuid references public.teams(id) on delete set null,
  opponent_match_team_id  uuid references public.match_teams(id) on delete set null,
  goals_for               int not null check (goals_for >= 0),
  goals_against           int not null check (goals_against >= 0),
  outcome                 char(1) not null check (outcome in ('W','D','L')),
  finished_at             timestamptz not null,
  recorded_at             timestamptz not null default now(),
  primary key (team_id, match_id)
);

create index if not exists team_match_history_team_finished_idx
  on public.team_match_history (team_id, finished_at desc);

create index if not exists team_match_history_match_idx
  on public.team_match_history (match_id);

alter table public.team_match_history enable row level security;

-- Read access: any user that can see the underlying match also sees its
-- aggregated history rows. Writes go strictly through SECURITY DEFINER paths.
drop policy if exists team_match_history_select_visible on public.team_match_history;
create policy team_match_history_select_visible
  on public.team_match_history for select
  to authenticated
  using (public.can_view_match(match_id, (select auth.uid())));

create table if not exists public.team_stats (
  team_id                  uuid primary key references public.teams(id) on delete cascade,
  matches_played           int not null default 0,
  wins                     int not null default 0,
  draws                    int not null default 0,
  losses                   int not null default 0,
  points                   int not null default 0,
  goals_for                int not null default 0,
  goals_against            int not null default 0,
  goal_difference          int generated always as (goals_for - goals_against) stored,
  clean_sheets             int not null default 0,
  current_win_streak       int not null default 0,
  current_unbeaten_streak  int not null default 0,
  longest_win_streak       int not null default 0,
  recent_form              text[] not null default array[]::text[],
  recent_matches           jsonb not null default '[]'::jsonb,
  player_goals             jsonb not null default '{}'::jsonb,
  last_finished_match_at   timestamptz,
  updated_at               timestamptz not null default now()
);

alter table public.team_stats enable row level security;

drop policy if exists team_stats_select_visible on public.team_stats;
create policy team_stats_select_visible
  on public.team_stats for select
  to authenticated
  using (
    -- Mirror teams_select_visible so any user that can see the team can see
    -- its aggregate stats. Writes are gated by SECURITY DEFINER triggers.
    exists (
      select 1
      from public.teams t
      where t.id = team_stats.team_id
        and (
          t.is_public
          or t.created_by = (select auth.uid())
          or exists (
            select 1 from public.team_members tm
            where tm.team_id = t.id and tm.user_id = (select auth.uid())
          )
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 2. Result parsing helpers
-- ---------------------------------------------------------------------------

-- `matches.cancellation_reason` doubles as a serialised result field for
-- two-team matches: 'teamAWins:3:1', 'teamBWins:0:2', 'draw:1:1'. Anything
-- else (e.g. 'cancelled_by_organizer') means we have no parseable scoreline.
create or replace function public.parse_match_result_token(p_value text)
returns table (kind text, score_a int, score_b int)
language plpgsql
immutable
set search_path = public
as $$
declare
  parts text[];
  v_kind text;
  v_a int;
  v_b int;
begin
  if p_value is null or btrim(p_value) = '' then
    return;
  end if;
  parts := string_to_array(p_value, ':');
  if array_length(parts, 1) <> 3 then
    return;
  end if;
  v_kind := parts[1];
  if v_kind not in ('teamAWins', 'teamBWins', 'draw') then
    return;
  end if;
  begin
    v_a := parts[2]::int;
    v_b := parts[3]::int;
  exception when others then
    return;
  end;
  if v_a < 0 or v_b < 0 then
    return;
  end if;
  kind := v_kind;
  score_a := v_a;
  score_b := v_b;
  return next;
end;
$$;

-- Resolves the canonical (teamA, teamB, scoreA, scoreB, finished_at) tuple for
-- a finished team match. Returns NULL row when the match is not eligible:
--   - status not 'finished'
--   - is_team_match=false
--   - missing match_teams slot 1/2 or missing source_team_id
--   - unparseable result + no finished fixture
create or replace function public.team_match_result(p_match_id uuid)
returns table (
  out_team_a_id uuid,
  out_team_b_id uuid,
  out_match_team_a_id uuid,
  out_match_team_b_id uuid,
  out_score_a int,
  out_score_b int,
  out_finished_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
#variable_conflict use_variable
declare
  v_match_status text;
  v_is_team_match boolean;
  v_match_finished_at timestamptz;
  v_cancellation_reason text;
  v_ta_id uuid;
  v_ta_source uuid;
  v_tb_id uuid;
  v_tb_source uuid;
  parsed record;
  fx record;
begin
  select status, is_team_match, finished_at, cancellation_reason
  into v_match_status, v_is_team_match, v_match_finished_at, v_cancellation_reason
  from public.matches
  where id = p_match_id;
  if not found or v_match_status <> 'finished' or v_is_team_match is not true then
    return;
  end if;

  select id, source_team_id into v_ta_id, v_ta_source
  from public.match_teams
  where match_id = p_match_id and team_slot = 1
  limit 1;
  if not found or v_ta_source is null then
    return;
  end if;

  select id, source_team_id into v_tb_id, v_tb_source
  from public.match_teams
  where match_id = p_match_id and team_slot = 2
  limit 1;
  if not found or v_tb_source is null then
    return;
  end if;

  -- Prefer cancellation_reason since `finishMatch` always writes it for
  -- two-team matches; fall back to the latest finished fixture for parity
  -- with `_outcomeForUser` in the Flutter client.
  select * into parsed from public.parse_match_result_token(v_cancellation_reason);
  if found then
    out_team_a_id := v_ta_source;
    out_team_b_id := v_tb_source;
    out_match_team_a_id := v_ta_id;
    out_match_team_b_id := v_tb_id;
    out_score_a := parsed.score_a;
    out_score_b := parsed.score_b;
    out_finished_at := coalesce(v_match_finished_at, now());
    return next;
    return;
  end if;

  select home_match_team_id, away_match_team_id, home_score, away_score, finished_at
  into fx
  from public.match_fixtures
  where match_id = p_match_id and status = 'finished'
    and home_score is not null and away_score is not null
  order by finished_at desc nulls last
  limit 1;
  if not found then
    return;
  end if;

  if fx.home_match_team_id = v_ta_id and fx.away_match_team_id = v_tb_id then
    out_score_a := fx.home_score;
    out_score_b := fx.away_score;
  elsif fx.home_match_team_id = v_tb_id and fx.away_match_team_id = v_ta_id then
    out_score_a := fx.away_score;
    out_score_b := fx.home_score;
  else
    return;
  end if;

  out_team_a_id := v_ta_source;
  out_team_b_id := v_tb_source;
  out_match_team_a_id := v_ta_id;
  out_match_team_b_id := v_tb_id;
  out_finished_at := coalesce(fx.finished_at, v_match_finished_at, now());
  return next;
end;
$$;

grant execute on function public.team_match_result(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. History journal mutators
-- ---------------------------------------------------------------------------

-- Apply (insert or refresh) the two history rows for a match. Idempotent.
-- Returns the affected team_ids so the caller can recompute aggregates.
create or replace function public._apply_team_match_history(p_match_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  affected uuid[] := array[]::uuid[];
  outcome_a char(1);
  outcome_b char(1);
begin
  select * into r from public.team_match_result(p_match_id);
  if not found or r.out_team_a_id is null or r.out_team_b_id is null then
    return affected;
  end if;

  if r.out_score_a > r.out_score_b then
    outcome_a := 'W'; outcome_b := 'L';
  elsif r.out_score_a < r.out_score_b then
    outcome_a := 'L'; outcome_b := 'W';
  else
    outcome_a := 'D'; outcome_b := 'D';
  end if;

  insert into public.team_match_history (
    team_id, match_id, match_team_id,
    opponent_team_id, opponent_match_team_id,
    goals_for, goals_against, outcome, finished_at, recorded_at
  ) values (
    r.out_team_a_id, p_match_id, r.out_match_team_a_id,
    r.out_team_b_id, r.out_match_team_b_id,
    r.out_score_a, r.out_score_b, outcome_a, r.out_finished_at, now()
  )
  on conflict (team_id, match_id) do update
    set match_team_id           = excluded.match_team_id,
        opponent_team_id        = excluded.opponent_team_id,
        opponent_match_team_id  = excluded.opponent_match_team_id,
        goals_for               = excluded.goals_for,
        goals_against           = excluded.goals_against,
        outcome                 = excluded.outcome,
        finished_at             = excluded.finished_at,
        recorded_at             = now();

  insert into public.team_match_history (
    team_id, match_id, match_team_id,
    opponent_team_id, opponent_match_team_id,
    goals_for, goals_against, outcome, finished_at, recorded_at
  ) values (
    r.out_team_b_id, p_match_id, r.out_match_team_b_id,
    r.out_team_a_id, r.out_match_team_a_id,
    r.out_score_b, r.out_score_a, outcome_b, r.out_finished_at, now()
  )
  on conflict (team_id, match_id) do update
    set match_team_id           = excluded.match_team_id,
        opponent_team_id        = excluded.opponent_team_id,
        opponent_match_team_id  = excluded.opponent_match_team_id,
        goals_for               = excluded.goals_for,
        goals_against           = excluded.goals_against,
        outcome                 = excluded.outcome,
        finished_at             = excluded.finished_at,
        recorded_at             = now();

  affected := array[r.out_team_a_id, r.out_team_b_id];
  return affected;
end;
$$;

grant execute on function public._apply_team_match_history(uuid) to service_role;

-- Returns the team_ids that previously had history for this match, then
-- removes those rows. Caller recomputes stats afterwards.
create or replace function public._clear_team_match_history(p_match_id uuid)
returns uuid[]
language plpgsql
security definer
set search_path = public
as $$
declare
  affected uuid[];
begin
  select coalesce(array_agg(distinct tmh.team_id), array[]::uuid[]) into affected
  from public.team_match_history tmh
  where tmh.match_id = p_match_id;

  if affected is not null and array_length(affected, 1) > 0 then
    delete from public.team_match_history tmh where tmh.match_id = p_match_id;
  end if;

  return coalesce(affected, array[]::uuid[]);
end;
$$;

grant execute on function public._clear_team_match_history(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Aggregate recomputation (full-rebuild from the journal)
-- ---------------------------------------------------------------------------

-- Rebuilds `team_stats` for one team purely from `team_match_history`
-- (+ `match_participant_goals` for the per-team scorers map). Always
-- converges to the same result, so safe to call repeatedly.
create or replace function public._recompute_team_stats(p_team_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_matches int := 0;
  v_wins int := 0;
  v_draws int := 0;
  v_losses int := 0;
  v_gf int := 0;
  v_ga int := 0;
  v_clean int := 0;
  v_last timestamptz;
  v_form text[] := array[]::text[];
  v_recent jsonb := '[]'::jsonb;
  v_player_goals jsonb := '{}'::jsonb;
  v_streak_w int := 0;
  v_streak_unbeaten int := 0;
  v_longest_w int := 0;
  v_streak_w_locked boolean := false;
  v_streak_unbeaten_locked boolean := false;
  ord record;
begin
  if p_team_id is null then
    return;
  end if;

  -- Counters + most-recent timestamp.
  select
    count(*),
    count(*) filter (where outcome = 'W'),
    count(*) filter (where outcome = 'D'),
    count(*) filter (where outcome = 'L'),
    coalesce(sum(goals_for), 0),
    coalesce(sum(goals_against), 0),
    count(*) filter (where goals_against = 0),
    max(finished_at)
  into v_matches, v_wins, v_draws, v_losses, v_gf, v_ga, v_clean, v_last
  from public.team_match_history
  where team_id = p_team_id;

  -- Recent form (last 5).
  select array_agg(outcome order by rn) into v_form
  from (
    select outcome,
           row_number() over (order by finished_at desc, match_id) as rn
    from public.team_match_history
    where team_id = p_team_id
    order by finished_at desc, match_id
    limit 5
  ) s;
  v_form := coalesce(v_form, array[]::text[]);

  -- Recent matches snapshot (last 10) embedded as jsonb so the Flutter UI can
  -- render opponent + score + outcome without N joins. Field names mirror the
  -- consumer (`team_details_screen._recentMatchTile`).
  select coalesce(jsonb_agg(payload order by finished_at desc, match_id), '[]'::jsonb)
  into v_recent
  from (
    select tmh.match_id,
           tmh.finished_at,
           jsonb_build_object(
             'matchId', tmh.match_id,
             'matchTitle', m.title,
             'finishedAt', tmh.finished_at,
             'playedAt', tmh.finished_at,
             'goalsFor', tmh.goals_for,
             'goalsAgainst', tmh.goals_against,
             'score', tmh.goals_for::text || ':' || tmh.goals_against::text,
             'outcome', tmh.outcome,
             'result', case tmh.outcome
                         when 'W' then 'win'
                         when 'L' then 'loss'
                         else 'draw'
                       end,
             'opponentTeamId', tmh.opponent_team_id,
             'opponentName', coalesce(t.name, mt.display_name, 'Opponent'),
             'isHome', mt2.team_slot = 1
           ) as payload
    from public.team_match_history tmh
    left join public.matches m on m.id = tmh.match_id
    left join public.teams t on t.id = tmh.opponent_team_id
    left join public.match_teams mt on mt.id = tmh.opponent_match_team_id
    left join public.match_teams mt2 on mt2.id = tmh.match_team_id
    where tmh.team_id = p_team_id
    order by tmh.finished_at desc, tmh.match_id
    limit 10
  ) ranked;

  -- Per-team scorers: only goals scored while playing for THIS team.
  select coalesce(jsonb_object_agg(player_id, total_goals), '{}'::jsonb)
  into v_player_goals
  from (
    select mpg.player_id::text,
           sum(mpg.goals)::int as total_goals
    from public.match_participant_goals mpg
    join public.team_match_history tmh
      on tmh.match_id = mpg.match_id and tmh.team_id = p_team_id
    join public.match_team_rosters mtr
      on mtr.match_team_id = tmh.match_team_id
     and mtr.player_id = mpg.player_id
     and mtr.status <> 'declined'
    group by mpg.player_id
    order by total_goals desc
    limit 25
  ) tg;

  -- Current streaks: walk history newest-first and freeze each counter at the
  -- first interruption. Lock flags ensure subsequent matches cannot extend a
  -- streak that has already been broken.
  for ord in
    select outcome, finished_at, match_id
    from public.team_match_history
    where team_id = p_team_id
    order by finished_at desc, match_id
  loop
    if not v_streak_w_locked then
      if ord.outcome = 'W' then
        v_streak_w := v_streak_w + 1;
      else
        v_streak_w_locked := true;
      end if;
    end if;

    if not v_streak_unbeaten_locked then
      if ord.outcome in ('W','D') then
        v_streak_unbeaten := v_streak_unbeaten + 1;
      else
        v_streak_unbeaten_locked := true;
      end if;
    end if;

    exit when v_streak_w_locked and v_streak_unbeaten_locked;
  end loop;

  -- Longest win streak: oldest-first scan.
  declare
    run int := 0;
  begin
    for ord in
      select outcome
      from public.team_match_history
      where team_id = p_team_id
      order by finished_at asc, match_id
    loop
      if ord.outcome = 'W' then
        run := run + 1;
        if run > v_longest_w then v_longest_w := run; end if;
      else
        run := 0;
      end if;
    end loop;
  end;

  insert into public.team_stats (
    team_id, matches_played, wins, draws, losses, points,
    goals_for, goals_against, clean_sheets,
    current_win_streak, current_unbeaten_streak, longest_win_streak,
    recent_form, recent_matches, player_goals,
    last_finished_match_at, updated_at
  )
  values (
    p_team_id, v_matches, v_wins, v_draws, v_losses, v_wins * 3 + v_draws,
    v_gf, v_ga, v_clean,
    v_streak_w, v_streak_unbeaten, v_longest_w,
    v_form, v_recent, v_player_goals,
    v_last, now()
  )
  on conflict (team_id) do update
    set matches_played          = excluded.matches_played,
        wins                    = excluded.wins,
        draws                   = excluded.draws,
        losses                  = excluded.losses,
        points                  = excluded.points,
        goals_for               = excluded.goals_for,
        goals_against           = excluded.goals_against,
        clean_sheets            = excluded.clean_sheets,
        current_win_streak      = excluded.current_win_streak,
        current_unbeaten_streak = excluded.current_unbeaten_streak,
        longest_win_streak      = excluded.longest_win_streak,
        recent_form             = excluded.recent_form,
        recent_matches          = excluded.recent_matches,
        player_goals            = excluded.player_goals,
        last_finished_match_at  = excluded.last_finished_match_at,
        updated_at              = now();
end;
$$;

grant execute on function public._recompute_team_stats(uuid) to service_role;

-- Public RPC: run a full rebuild for one team (e.g. after manual data repair).
create or replace function public.recompute_team_stats(p_team_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if not (
    public.is_team_officer(p_team_id, v_uid)
    or public.is_admin()
  ) then
    raise exception 'Only team officers or admins can recompute team stats';
  end if;
  perform public._recompute_team_stats(p_team_id);
  return jsonb_build_object('success', true, 'teamId', p_team_id);
end;
$$;

grant execute on function public.recompute_team_stats(uuid)
  to authenticated, service_role;

-- Public RPC: rebuild every team's aggregates. Admin-only.
create or replace function public.recompute_all_team_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_team_id uuid;
  v_count int := 0;
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'Admin required';
  end if;
  for v_team_id in select id from public.teams loop
    perform public._recompute_team_stats(v_team_id);
    v_count := v_count + 1;
  end loop;
  return jsonb_build_object('success', true, 'teamsRecomputed', v_count);
end;
$$;

grant execute on function public.recompute_all_team_stats()
  to authenticated, service_role;

-- Public RPC: rebuild the entire history journal from `matches`. Admin-only.
-- Useful when the journal becomes inconsistent with the underlying matches.
create or replace function public.rebuild_team_match_history()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match record;
  v_applied int := 0;
  v_team_id uuid;
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'Admin required';
  end if;

  delete from public.team_match_history;
  for v_match in
    select id from public.matches
    where status = 'finished' and is_team_match is true
  loop
    perform public._apply_team_match_history(v_match.id);
    v_applied := v_applied + 1;
  end loop;

  for v_team_id in select id from public.teams loop
    perform public._recompute_team_stats(v_team_id);
  end loop;

  return jsonb_build_object('success', true, 'matchesProcessed', v_applied);
end;
$$;

grant execute on function public.rebuild_team_match_history()
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. Triggers — keep team_stats in sync automatically
-- ---------------------------------------------------------------------------

-- A. Match status / score changes drive history mutations.
create or replace function public._sync_team_stats_on_match_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected uuid[] := array[]::uuid[];
  cleared uuid[] := array[]::uuid[];
  v_team_id uuid;
  was_finished boolean := false;
  is_finished boolean := false;
begin
  if tg_op = 'DELETE' then
    cleared := public._clear_team_match_history(old.id);
    foreach v_team_id in array cleared loop
      perform public._recompute_team_stats(v_team_id);
    end loop;
    return old;
  end if;

  is_finished := (new.status = 'finished' and new.is_team_match is true);
  if tg_op = 'UPDATE' then
    was_finished := (old.status = 'finished' and old.is_team_match is true);
  end if;

  if is_finished then
    affected := public._apply_team_match_history(new.id);
    -- If the match flips between team types or scores change, prior history
    -- rows for THIS match might point to ex-teams that are no longer in the
    -- result tuple. Detect and recompute them too.
    select coalesce(array_agg(tmh.team_id), array[]::uuid[]) into cleared
    from public.team_match_history tmh
    where tmh.match_id = new.id
      and tmh.team_id <> all(coalesce(affected, array[]::uuid[]));
    if array_length(cleared, 1) is not null and array_length(cleared, 1) > 0 then
      delete from public.team_match_history tmh
      where tmh.match_id = new.id and tmh.team_id = any(cleared);
    end if;
  elsif was_finished or tg_op = 'INSERT' then
    -- Match no longer finished (cancelled, reopened) — purge history for it.
    cleared := public._clear_team_match_history(new.id);
  end if;

  for v_team_id in
    select distinct unnest(
      coalesce(affected, array[]::uuid[]) || coalesce(cleared, array[]::uuid[])
    )
  loop
    perform public._recompute_team_stats(v_team_id);
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_sync_team_stats_on_match_update on public.matches;
create trigger trg_sync_team_stats_on_match_update
after update of status, cancellation_reason, finished_at, is_team_match
on public.matches
for each row
execute function public._sync_team_stats_on_match_change();

drop trigger if exists trg_sync_team_stats_on_match_insert on public.matches;
create trigger trg_sync_team_stats_on_match_insert
after insert on public.matches
for each row
when (new.status = 'finished' and new.is_team_match is true)
execute function public._sync_team_stats_on_match_change();

drop trigger if exists trg_sync_team_stats_on_match_delete on public.matches;
create trigger trg_sync_team_stats_on_match_delete
before delete on public.matches
for each row
when (old.is_team_match is true)
execute function public._sync_team_stats_on_match_change();

-- B. Match-team membership changes (e.g. organiser relabels slot 1 ↔ 2 or sets
-- a missing source_team_id) need to be reflected. We only fire on team match
-- rows whose match is already finished, otherwise there is nothing to recompute.
create or replace function public._sync_team_stats_on_match_team_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected uuid[] := array[]::uuid[];
  v_team_id uuid;
  v_match_id uuid := coalesce(new.match_id, old.match_id);
  v_match_status text;
  v_is_team_match boolean;
begin
  select status, is_team_match into v_match_status, v_is_team_match
  from public.matches where id = v_match_id;

  if v_match_status is null
     or v_match_status <> 'finished'
     or v_is_team_match is not true then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    perform public._clear_team_match_history(v_match_id);
  else
    affected := public._apply_team_match_history(v_match_id);
  end if;

  -- Recompute every team that previously / currently has history for this
  -- match, not just the new pair (handles slot remap).
  for v_team_id in
    select distinct tmh.team_id
    from public.team_match_history tmh
    where tmh.match_id = v_match_id
    union
    select unnest(coalesce(affected, array[]::uuid[]))
  loop
    perform public._recompute_team_stats(v_team_id);
  end loop;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_team_stats_on_match_team_change on public.match_teams;
create trigger trg_sync_team_stats_on_match_team_change
after insert or update of team_slot, source_team_id, display_name or delete
on public.match_teams
for each row
execute function public._sync_team_stats_on_match_team_change();

-- C. Per-player goals only feed the player_goals jsonb. Recomputes are cheap.
create or replace function public._sync_team_stats_on_player_goals_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid := coalesce(new.match_id, old.match_id);
  v_team_id uuid;
begin
  for v_team_id in
    select distinct tmh.team_id
    from public.team_match_history tmh
    where tmh.match_id = v_match_id
  loop
    perform public._recompute_team_stats(v_team_id);
  end loop;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_team_stats_on_player_goals_change on public.match_participant_goals;
create trigger trg_sync_team_stats_on_player_goals_change
after insert or update or delete on public.match_participant_goals
for each row execute function public._sync_team_stats_on_player_goals_change();

-- D. Roster shifts can change player_goals attribution (player wasn't on the
-- team's roster at finalisation time). Cheap recompute keyed by team via
-- match_team -> team_match_history join.
create or replace function public._sync_team_stats_on_roster_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_team_id uuid := coalesce(new.match_team_id, old.match_team_id);
  v_team_id uuid;
begin
  for v_team_id in
    select distinct tmh.team_id
    from public.team_match_history tmh
    where tmh.match_team_id = v_match_team_id
  loop
    perform public._recompute_team_stats(v_team_id);
  end loop;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_sync_team_stats_on_roster_change on public.match_team_rosters;
create trigger trg_sync_team_stats_on_roster_change
after insert or update of status, player_id or delete
on public.match_team_rosters
for each row execute function public._sync_team_stats_on_roster_change();

-- ---------------------------------------------------------------------------
-- 6. One-time backfill
-- ---------------------------------------------------------------------------

do $$
declare
  v_match record;
  v_team_id uuid;
begin
  -- Wipe and rebuild from the journal so we converge to a clean state.
  delete from public.team_match_history;

  for v_match in
    select id from public.matches
    where status = 'finished' and is_team_match is true
  loop
    perform public._apply_team_match_history(v_match.id);
  end loop;

  -- Make sure every team has a row, even those without finished team matches
  -- (otherwise the realtime stream would stay empty for them).
  insert into public.team_stats (team_id)
  select t.id from public.teams t
  on conflict (team_id) do nothing;

  for v_team_id in select id from public.teams loop
    perform public._recompute_team_stats(v_team_id);
  end loop;
end $$;
