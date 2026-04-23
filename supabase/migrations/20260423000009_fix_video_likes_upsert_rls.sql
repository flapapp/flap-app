-- Allow authenticated users to upsert their own video likes.
-- The app uses upsert(video_id, user_id), which may execute UPDATE on conflict.
-- Without an UPDATE policy, Postgres rejects the operation under RLS.

drop policy if exists video_likes_update_own on public.video_likes;
create policy video_likes_update_own
  on public.video_likes for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
