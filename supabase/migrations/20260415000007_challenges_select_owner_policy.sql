-- Non-recursive path for SELECT: the audience policy calls is_challenge_visible_to_user,
-- which reads challenges again. A direct owner clause lets creators read their row
-- (and satisfies INSERT … RETURNING if the client uses it).
begin;

drop policy if exists "challenge creators can select own challenges" on public.challenges;

create policy "challenge creators can select own challenges"
on public.challenges
for select
using (deleted_at is null and auth.uid() = user_id);

commit;
