-- Match status changes (e.g. finishing a match) were not appearing on other
-- participants' devices until the app was reopened. The match details and
-- management screens subscribe to the `matches` table via supabase_flutter
-- `.stream()`, which only receives live INSERT/UPDATE/DELETE events when the
-- table is a member of the `supabase_realtime` publication. `matches` was never
-- added, so a `.stream()` on it emitted only its initial snapshot and never the
-- status → 'finished' UPDATE. Re-opening the app re-subscribed and re-fetched,
-- which is why the change "showed up eventually".
--
-- Add `matches` to the realtime publication so the status transition is pushed
-- to every subscribed client. The screens' streams ignore the payload and
-- re-fetch the full joined match row on any event, so the embedded score/goals
-- refresh alongside the status — publishing `matches` alone is sufficient.
-- REPLICA IDENTITY FULL makes UPDATE events carry the full row so filtered
-- streams and status transitions are delivered reliably.
--
-- Guarded so re-running is a no-op (ALTER PUBLICATION ... ADD TABLE errors if
-- the table is already a member).

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'matches'
  ) then
    alter publication supabase_realtime add table public.matches;
  end if;
end $$;

alter table public.matches replica identity full;
