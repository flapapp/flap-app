alter table public.match_teams
  add column if not exists team_total_rating double precision not null default 0;
