-- Allow upsert on challenge_participants (INSERT ... ON CONFLICT → UPDATE under RLS).
-- Without an UPDATE policy, the conflict branch fails with RLS 42501.

drop policy if exists challenge_participants_update_self_or_creator on public.challenge_participants;
create policy challenge_participants_update_self_or_creator
  on public.challenge_participants for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
  )
  with check (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
  );
