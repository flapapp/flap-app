-- Squad players linked to auth users; extends clubs (teams) for creation wizard.
-- Existing `public.teams` stays compatible; new columns are nullable.

do $$ begin
  create type public.player_position as enum ('GK', 'DF', 'MF', 'FW');
exception
  when duplicate_object then null;
end $$;

alter table public.teams
  add column if not exists short_name text,
  add column if not exists founded_year integer,
  add column if not exists country text,
  add column if not exists primary_color text,
  add column if not exists secondary_color text;

alter table public.teams drop constraint if exists teams_short_name_len;
alter table public.teams
  add constraint teams_short_name_len
  check (short_name is null or char_length(short_name) <= 5);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  position public.player_position not null,
  jersey_number integer not null,
  age integer,
  nationality text,
  created_at timestamptz not null default now(),
  constraint players_team_jersey_unique unique (team_id, jersey_number),
  constraint players_jersey_positive check (jersey_number >= 1 and jersey_number <= 99)
);

create index if not exists players_team_id_idx on public.players (team_id);
create index if not exists players_user_id_idx on public.players (user_id);

alter table public.players enable row level security;

create policy players_select_authenticated
  on public.players for select
  to authenticated
  using (true);

create policy players_insert_captain_self
  on public.players for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.teams t
      where t.id = team_id
        and t.captain_id = auth.uid()
    )
  );

create policy players_update_captain_self
  on public.players for update
  to authenticated
  using (
    exists (
      select 1 from public.teams t
      where t.id = players.team_id
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );

create policy players_delete_captain
  on public.players for delete
  to authenticated
  using (
    exists (
      select 1 from public.teams t
      where t.id = players.team_id
        and t.captain_id = auth.uid()
    )
  );

-- Atomic: reuse team_create (caps + membership) then club fields + squad rows.
create or replace function public.team_create_with_squad(
  p_name text,
  p_description text,
  p_city text,
  p_is_public boolean,
  p_short_name text,
  p_founded_year integer,
  p_country text,
  p_primary_color text,
  p_secondary_color text,
  p_players jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_elem jsonb;
  v_pos public.player_position;
  v_name text;
  v_jersey int;
  v_age int;
  v_nat text;
  v_len int;
  v_distinct int;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if p_players is null or jsonb_typeof(p_players) <> 'array' then
    raise exception 'invalid_players' using errcode = 'P0001';
  end if;

  v_len := jsonb_array_length(p_players);
  if v_len < 11 then
    raise exception 'squad_too_small' using errcode = 'P0001';
  end if;

  select count(*)::int into v_distinct
  from (
    select distinct (e->>'jersey_number')::int as j
    from jsonb_array_elements(p_players) e
  ) s;

  if v_distinct <> v_len then
    raise exception 'duplicate_jersey' using errcode = 'P0001';
  end if;

  v_id := public.team_create(
    p_name,
    coalesce(p_description, ''),
    p_city,
    coalesce(p_is_public, true)
  );

  update public.teams
  set
    short_name = nullif(trim(p_short_name), ''),
    founded_year = p_founded_year,
    country = nullif(trim(p_country), ''),
    primary_color = nullif(trim(p_primary_color), ''),
    secondary_color = nullif(trim(p_secondary_color), ''),
    updated_at = now()
  where id = v_id;

  for v_elem in select * from jsonb_array_elements(p_players)
  loop
    v_name := coalesce(nullif(trim(v_elem->>'name'), ''), 'Player');
    v_pos := (v_elem->>'position')::public.player_position;
    v_jersey := (v_elem->>'jersey_number')::int;
    v_age := nullif(v_elem->>'age', '')::int;
    v_nat := nullif(trim(v_elem->>'nationality'), '');

    insert into public.players (
      team_id, user_id, name, position, jersey_number, age, nationality
    ) values (
      v_id, v_uid, v_name, v_pos, v_jersey, v_age, v_nat
    );
  end loop;

  return v_id;
end;
$$;

grant execute on function public.team_create_with_squad(
  text, text, text, boolean,
  text, integer, text, text, text,
  jsonb
) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'players'
  ) then
    alter publication supabase_realtime add table public.players;
  end if;
exception
  when duplicate_object then null;
end $$;
