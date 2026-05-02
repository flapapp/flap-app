-- Per-player goals for a finished match (two-team flow without match_fixtures).
-- Existing match_player_goals ties rows to match_fixture_id; casual 2-team matches often have no fixtures.

create table public.match_participant_goals (
  match_id uuid not null references public.matches (id) on delete cascade,
  player_id uuid not null references public.profiles (id) on delete cascade,
  goals integer not null check (goals >= 0),
  primary key (match_id, player_id)
);

create index match_participant_goals_match_idx
  on public.match_participant_goals (match_id);

alter table public.match_participant_goals enable row level security;

create policy match_participant_goals_select_if_match_visible
  on public.match_participant_goals for select
  to authenticated
  using (public.can_view_match(match_id, (select auth.uid())));

create policy match_participant_goals_mutate_organizer
  on public.match_participant_goals for all
  to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  );
