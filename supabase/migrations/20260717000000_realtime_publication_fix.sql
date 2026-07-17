-- Realtime publication correction.
--
-- An audit of every supabase_flutter `.stream()` in the app cross-referenced
-- against `pg_publication_tables` for `supabase_realtime` turned up two
-- mismatches:
--
-- 1. THREE tables the app still streams were never added to the publication,
--    so their `.stream()` calls only ever emitted the initial snapshot and
--    never a live INSERT/UPDATE/DELETE — the same defect the `matches`
--    migration (20260715000000) fixed for that one table:
--      * notifications        — the list and the unread badge never updated
--                               until the app was reopened (re-subscribe).
--      * match_invites        — a new invite stayed invisible on the match
--                               management screen until reopen.
--      * match_participants   — match details streams `matches` (already
--                               published) AND `match_participants` side by
--                               side; only the former was live, so a player
--                               joining/accepting did not appear until reopen.
--    Add all three, with REPLICA IDENTITY FULL so UPDATE events carry the full
--    row for the screens' filtered streams (they ignore the payload and
--    re-fetch on any event, so publishing the base table is sufficient).
--
-- 2. TWO tables remain in the publication with no subscriber left. The app no
--    longer streams either — `match_photos` was moved to query/refresh and
--    `team_match_request_players` was never streamed. Both still carry REPLICA
--    IDENTITY FULL, which under wal_level=logical writes the entire old row to
--    WAL on every UPDATE/DELETE regardless of publication membership. Drop them
--    from the publication AND reset their replica identity to default so the
--    WAL overhead actually stops.
--
-- Every step is guarded so re-running the migration is a no-op (ALTER
-- PUBLICATION ... ADD/DROP TABLE errors if the membership already matches).

-- 1. Add the three tables that should have been live all along. ---------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_invites'
  ) then
    alter publication supabase_realtime add table public.match_invites;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_participants'
  ) then
    alter publication supabase_realtime add table public.match_participants;
  end if;
end $$;

alter table public.notifications replica identity full;
alter table public.match_invites replica identity full;
alter table public.match_participants replica identity full;

-- 2. Drop the two tables nothing subscribes to, and stop their WAL overhead. ---
do $$
begin
  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_photos'
  ) then
    alter publication supabase_realtime drop table public.match_photos;
  end if;

  if exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'team_match_request_players'
  ) then
    alter publication supabase_realtime drop table public.team_match_request_players;
  end if;
end $$;

alter table public.match_photos replica identity default;
alter table public.team_match_request_players replica identity default;
