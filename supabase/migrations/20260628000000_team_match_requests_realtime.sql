-- Team match invitations were not reaching the target captain in real time:
-- the receiving side watches `team_match_requests` via supabase_flutter
-- `.stream()`, which depends on the table being part of the `supabase_realtime`
-- publication. Without it, the stream only ever emits its initial snapshot and
-- never receives live INSERTs, so a new invite stayed invisible until the
-- captain re-opened the screen (re-subscribing and re-fetching). Add the
-- request tables (and their roster child) to the realtime publication.
--
-- Guarded so re-running is a no-op (ALTER PUBLICATION ... ADD TABLE errors if
-- the table is already a member). REPLICA IDENTITY FULL ensures realtime
-- delivers complete old/new rows for UPDATE/DELETE (status changes), since
-- these tables don't always carry every column in the default identity.

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'team_match_requests'
  ) then
    alter publication supabase_realtime add table public.team_match_requests;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'team_match_request_players'
  ) then
    alter publication supabase_realtime add table public.team_match_request_players;
  end if;
end $$;

alter table public.team_match_requests replica identity full;
alter table public.team_match_request_players replica identity full;
