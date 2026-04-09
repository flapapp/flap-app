-- Matches (migrated from Firestore `matches` + subcollection `fixtures`).
-- Authorization for mutations is enforced in the app layer (same as legacy Firestore rules).

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null,
  status text not null,
  match_date timestamptz not null,
  finished_at timestamptz,
  participants uuid[] not null default '{}',
  document jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint matches_status_check check (
    status in ('open', 'full', 'inProgress', 'finished', 'cancelled')
  )
);

create index if not exists matches_status_match_date_idx
  on public.matches (status, match_date);

create index if not exists matches_participants_gin
  on public.matches using gin (participants);

create index if not exists matches_organizer_idx
  on public.matches (organizer_id);

create index if not exists matches_finished_at_idx
  on public.matches (finished_at desc nulls last);

create table if not exists public.match_fixtures (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  team_a_index int,
  team_b_index int,
  team_a_name text,
  team_b_name text,
  score_a int,
  score_b int,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists match_fixtures_match_id_idx
  on public.match_fixtures (match_id);

-- Win / loss / draw counters used when finishing a match (mirrors legacy Firestore user fields).
alter table public.profiles add column if not exists wins integer default 0;
alter table public.profiles add column if not exists losses integer default 0;
alter table public.profiles add column if not exists draws integer default 0;

alter table public.matches enable row level security;
alter table public.match_fixtures enable row level security;

drop policy if exists matches_select_authenticated on public.matches;
create policy matches_select_authenticated
  on public.matches for select
  to authenticated
  using (true);

drop policy if exists matches_insert_authenticated on public.matches;
create policy matches_insert_authenticated
  on public.matches for insert
  to authenticated
  with check (organizer_id = auth.uid());

drop policy if exists matches_update_authenticated on public.matches;
create policy matches_update_authenticated
  on public.matches for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists matches_delete_authenticated on public.matches;
create policy matches_delete_authenticated
  on public.matches for delete
  to authenticated
  using (organizer_id = auth.uid());

drop policy if exists match_fixtures_all_authenticated on public.match_fixtures;
create policy match_fixtures_all_authenticated
  on public.match_fixtures for all
  to authenticated
  using (true)
  with check (true);
