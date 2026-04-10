-- Clubs / squads (replaces Firestore `teams`, `teamInvites`, `teamJoinRequests`, `teamMatchRequests`, `team_activity`).

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_lower text not null,
  description text not null default '',
  captain_id uuid not null references public.profiles (id) on delete restrict,
  vice_captain_ids uuid[] not null default '{}',
  member_ids uuid[] not null default '{}',
  is_public boolean not null default true,
  logo_url text,
  city text,
  wins integer not null default 0,
  losses integer not null default 0,
  draws integer not null default 0,
  goals_for integer not null default 0,
  goals_against integer not null default 0,
  player_goals jsonb not null default '{}'::jsonb,
  recent_matches jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists teams_member_ids_gin on public.teams using gin (member_ids);
create index if not exists teams_name_lower_idx on public.teams (name_lower);
create index if not exists teams_is_public_idx on public.teams (is_public);

create table if not exists public.team_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  team_name text not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  invited_by uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists team_invites_user_pending_idx
  on public.team_invites (user_id, status);

create table if not exists public.team_join_requests (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  team_name text not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  user_name text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists team_join_requests_team_pending_idx
  on public.team_join_requests (team_id, status);

create table if not exists public.team_match_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  team_id uuid not null references public.teams (id) on delete cascade,
  opponent_team_id text not null,
  opponent_name text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending',
  proposed_roster uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists team_match_requests_team_pending_idx
  on public.team_match_requests (team_id, status);

create table if not exists public.team_activity (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  team_id uuid not null references public.teams (id) on delete cascade,
  team_name text not null,
  user_id uuid not null,
  user_name text not null,
  created_at timestamptz not null default now()
);

create index if not exists team_activity_created_idx
  on public.team_activity (created_at desc);

alter table public.teams enable row level security;
alter table public.team_invites enable row level security;
alter table public.team_join_requests enable row level security;
alter table public.team_match_requests enable row level security;
alter table public.team_activity enable row level security;

-- Read: any signed-in client (same broad model as legacy Firestore queries).
create policy teams_select_authenticated
  on public.teams for select
  to authenticated
  using (true);

create policy teams_insert_authenticated
  on public.teams for insert
  to authenticated
  with check (captain_id = auth.uid());

create policy teams_update_managers
  on public.teams for update
  to authenticated
  using (
    captain_id = auth.uid()
    or auth.uid() = any (vice_captain_ids)
  );

create policy team_invites_select_authenticated
  on public.team_invites for select
  to authenticated
  using (true);

create policy team_invites_insert_managers
  on public.team_invites for insert
  to authenticated
  with check (
    invited_by = auth.uid()
    and exists (
      select 1 from public.teams t
      where t.id = team_id
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );

create policy team_invites_update_invitee
  on public.team_invites for update
  to authenticated
  using (user_id = auth.uid());

create policy team_join_requests_select_authenticated
  on public.team_join_requests for select
  to authenticated
  using (true);

create policy team_join_requests_insert_self
  on public.team_join_requests for insert
  to authenticated
  with check (user_id = auth.uid());

create policy team_join_requests_update_managers
  on public.team_join_requests for update
  to authenticated
  using (
    exists (
      select 1 from public.teams t
      where t.id = team_join_requests.team_id
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );

create policy team_match_requests_select_authenticated
  on public.team_match_requests for select
  to authenticated
  using (true);

create policy team_match_requests_insert_self
  on public.team_match_requests for insert
  to authenticated
  with check (created_by = auth.uid());

create policy team_match_requests_update_managers
  on public.team_match_requests for update
  to authenticated
  using (
    exists (
      select 1 from public.teams t
      where t.id = team_match_requests.team_id
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );

create policy team_activity_select_authenticated
  on public.team_activity for select
  to authenticated
  using (true);

create policy team_activity_insert_authenticated
  on public.team_activity for insert
  to authenticated
  with check (true);

-- Atomic create with 3-team-per-player cap (replaces Firestore transaction + users.teamIds).
create or replace function public.team_create(
  p_name text,
  p_description text,
  p_city text,
  p_is_public boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_count int;
  v_now timestamptz := now();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select count(*)::int into v_count
  from public.teams t
  where v_uid = any (t.member_ids);

  if v_count >= 3 then
    raise exception 'max_teams' using errcode = 'P0001';
  end if;

  insert into public.teams (
    name, name_lower, description, captain_id, vice_captain_ids, member_ids,
    is_public, city, created_at, updated_at
  ) values (
    p_name,
    lower(trim(p_name)),
    coalesce(p_description, ''),
    v_uid,
    '{}',
    array[v_uid]::uuid[],
    coalesce(p_is_public, true),
    nullif(trim(p_city), ''),
    v_now,
    v_now
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.team_create(text, text, text, boolean) to authenticated;

-- Invitee accepts/declines; on accept enforce 3-team cap and append member.
create or replace function public.team_invite_respond(
  p_invite_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.team_invites%rowtype;
  v_count int;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into r from public.team_invites where id = p_invite_id for update;
  if not found then
    raise exception 'invite_not_found' using errcode = 'P0001';
  end if;
  if r.user_id <> v_uid then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
  if r.status <> 'pending' then
    return;
  end if;

  update public.team_invites
  set status = case when p_accept then 'accepted' else 'declined' end,
      updated_at = now()
  where id = p_invite_id;

  if p_accept then
    select count(*)::int into v_count
    from public.teams t
    where v_uid = any (t.member_ids);

    if v_count >= 3 then
      raise exception 'max_teams' using errcode = 'P0001';
    end if;

    update public.teams
    set member_ids = (
      select coalesce(array_agg(distinct x), '{}'::uuid[])
      from unnest(member_ids || array[v_uid]::uuid[]) as x
    ),
        updated_at = now()
    where id = r.team_id;
  end if;
end;
$$;

grant execute on function public.team_invite_respond(uuid, boolean) to authenticated;

-- Captain / vice accepts or declines a join request.
create or replace function public.team_join_respond(
  p_request_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.team_join_requests%rowtype;
  t public.teams%rowtype;
  v_count int;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into r from public.team_join_requests where id = p_request_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0001';
  end if;
  if r.status <> 'pending' then
    return;
  end if;

  select * into t from public.teams where id = r.team_id for update;
  if not found then
    raise exception 'team_not_found' using errcode = 'P0001';
  end if;

  if v_uid <> t.captain_id and not (v_uid = any (t.vice_captain_ids)) then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  update public.team_join_requests
  set status = case when p_accept then 'accepted' else 'declined' end,
      updated_at = now()
  where id = p_request_id;

  if p_accept then
    select count(*)::int into v_count
    from public.teams x
    where r.user_id = any (x.member_ids);

    if v_count >= 3 then
      raise exception 'max_teams' using errcode = 'P0001';
    end if;

    update public.teams
    set member_ids = (
      select coalesce(array_agg(distinct y), '{}'::uuid[])
      from unnest(member_ids || array[r.user_id]::uuid[]) as y
    ),
        updated_at = now()
    where id = r.team_id;
  end if;
end;
$$;

grant execute on function public.team_join_respond(uuid, boolean) to authenticated;

-- Leave team + captain handoff (replaces Firestore transaction).
create or replace function public.team_leave(p_team_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  t public.teams%rowtype;
  v_members uuid[];
  v_vice uuid[];
  v_next uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into t from public.teams where id = p_team_id for update;
  if not found then
    raise exception 'team_not_found' using errcode = 'P0001';
  end if;

  v_members := t.member_ids;
  v_vice := t.vice_captain_ids;

  if not (v_uid = any (v_members)) then
    raise exception 'not_member' using errcode = 'P0001';
  end if;

  if t.captain_id = v_uid and array_length(v_members, 1) = 1 then
    raise exception 'last_member' using errcode = 'P0001';
  end if;

  v_members := array(
    select m from unnest(v_members) as m where m <> v_uid
  );
  v_vice := array(
    select m from unnest(v_vice) as m where m <> v_uid
  );

  if t.captain_id = v_uid then
    if array_length(v_vice, 1) >= 1 then
      v_next := v_vice[1];
    elsif array_length(v_members, 1) >= 1 then
      v_next := v_members[1];
    else
      raise exception 'no_successor' using errcode = 'P0001';
    end if;
    v_vice := array(
      select m from unnest(v_vice) as m where m <> v_next
    );
    update public.teams
    set captain_id = v_next,
        member_ids = v_members,
        vice_captain_ids = v_vice,
        updated_at = now()
    where id = p_team_id;
  else
    update public.teams
    set member_ids = v_members,
        vice_captain_ids = v_vice,
        updated_at = now()
    where id = p_team_id;
  end if;
end;
$$;

grant execute on function public.team_leave(uuid) to authenticated;

-- Apply match result to two team rows (caller sends final counters + json blobs).
create or replace function public.teams_set_standings_after_match(
  p_team_a_id uuid,
  p_team_a_wins int,
  p_team_a_losses int,
  p_team_a_draws int,
  p_team_a_goals_for int,
  p_team_a_goals_against int,
  p_team_a_player_goals jsonb,
  p_team_a_recent jsonb,
  p_team_b_id uuid,
  p_team_b_wins int,
  p_team_b_losses int,
  p_team_b_draws int,
  p_team_b_goals_for int,
  p_team_b_goals_against int,
  p_team_b_player_goals jsonb,
  p_team_b_recent jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  update public.teams
  set
    wins = p_team_a_wins,
    losses = p_team_a_losses,
    draws = p_team_a_draws,
    goals_for = p_team_a_goals_for,
    goals_against = p_team_a_goals_against,
    player_goals = coalesce(p_team_a_player_goals, '{}'::jsonb),
    recent_matches = coalesce(p_team_a_recent, '[]'::jsonb),
    updated_at = now()
  where id = p_team_a_id;

  update public.teams
  set
    wins = p_team_b_wins,
    losses = p_team_b_losses,
    draws = p_team_b_draws,
    goals_for = p_team_b_goals_for,
    goals_against = p_team_b_goals_against,
    player_goals = coalesce(p_team_b_player_goals, '{}'::jsonb),
    recent_matches = coalesce(p_team_b_recent, '[]'::jsonb),
    updated_at = now()
  where id = p_team_b_id;
end;
$$;

grant execute on function public.teams_set_standings_after_match(
  uuid, int, int, int, int, int, jsonb, jsonb,
  uuid, int, int, int, int, int, jsonb, jsonb
) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'teams'
  ) then
    alter publication supabase_realtime add table public.teams;
  end if;
exception
  when duplicate_object then null;
end $$;
