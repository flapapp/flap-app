-- After INSERT ... RETURNING, PostgREST re-evaluates SELECT RLS. The main policy
-- uses public.can_view_match() which can fail for edge cases (e.g. timing / viewer).
-- This permissive OR policy ensures the match creator can always read rows where
-- they are the organizer, which matches the INSERT with_check on the same table.

create policy matches_select_organizer
  on public.matches
  for select
  to authenticated
  using (organizer_id = (select auth.uid()));
