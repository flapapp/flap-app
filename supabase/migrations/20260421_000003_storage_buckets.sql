-- =============================================================================
-- Supabase Storage: buckets + object policies (public read, user-scoped writes)
-- Aligns with lib/core/supabase/supabase_app_storage.dart bucket ids.
-- =============================================================================

-- Public buckets for app media (URLs stored in Firestore / Supabase rows)
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('videos', 'videos', true),
  ('team-logos', 'team-logos', true),
  ('thumbnails', 'thumbnails', true),
  ('challenge-thumbnails', 'challenge-thumbnails', true),
  ('submission-thumbnails', 'submission-thumbnails', true),
  ('match-covers', 'match-covers', true)
on conflict (id) do update
set public = excluded.public;

-- Helper: first path segment must equal auth.uid() (user-owned prefix)
-- Policies are split per bucket so MIME limits can be added later per bucket.

-- avatars
drop policy if exists "storage_avatars_select" on storage.objects;
create policy "storage_avatars_select"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "storage_avatars_insert" on storage.objects;
create policy "storage_avatars_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_avatars_update" on storage.objects;
create policy "storage_avatars_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_avatars_delete" on storage.objects;
create policy "storage_avatars_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- videos
drop policy if exists "storage_videos_select" on storage.objects;
create policy "storage_videos_select"
  on storage.objects for select
  to public
  using (bucket_id = 'videos');

drop policy if exists "storage_videos_insert" on storage.objects;
create policy "storage_videos_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_videos_update" on storage.objects;
create policy "storage_videos_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_videos_delete" on storage.objects;
create policy "storage_videos_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- team-logos
drop policy if exists "storage_team_logos_select" on storage.objects;
create policy "storage_team_logos_select"
  on storage.objects for select
  to public
  using (bucket_id = 'team-logos');

drop policy if exists "storage_team_logos_insert" on storage.objects;
create policy "storage_team_logos_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_team_logos_update" on storage.objects;
create policy "storage_team_logos_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_team_logos_delete" on storage.objects;
create policy "storage_team_logos_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- thumbnails (video)
drop policy if exists "storage_thumbnails_select" on storage.objects;
create policy "storage_thumbnails_select"
  on storage.objects for select
  to public
  using (bucket_id = 'thumbnails');

drop policy if exists "storage_thumbnails_insert" on storage.objects;
create policy "storage_thumbnails_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_thumbnails_update" on storage.objects;
create policy "storage_thumbnails_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_thumbnails_delete" on storage.objects;
create policy "storage_thumbnails_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- challenge-thumbnails
drop policy if exists "storage_challenge_thumbnails_select" on storage.objects;
create policy "storage_challenge_thumbnails_select"
  on storage.objects for select
  to public
  using (bucket_id = 'challenge-thumbnails');

drop policy if exists "storage_challenge_thumbnails_insert" on storage.objects;
create policy "storage_challenge_thumbnails_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_challenge_thumbnails_update" on storage.objects;
create policy "storage_challenge_thumbnails_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_challenge_thumbnails_delete" on storage.objects;
create policy "storage_challenge_thumbnails_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- submission-thumbnails (path: {uid}/{challengeId}/file)
drop policy if exists "storage_submission_thumbnails_select" on storage.objects;
create policy "storage_submission_thumbnails_select"
  on storage.objects for select
  to public
  using (bucket_id = 'submission-thumbnails');

drop policy if exists "storage_submission_thumbnails_insert" on storage.objects;
create policy "storage_submission_thumbnails_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_submission_thumbnails_update" on storage.objects;
create policy "storage_submission_thumbnails_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_submission_thumbnails_delete" on storage.objects;
create policy "storage_submission_thumbnails_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- match-covers (path: {uid}/{matchId}/file)
drop policy if exists "storage_match_covers_select" on storage.objects;
create policy "storage_match_covers_select"
  on storage.objects for select
  to public
  using (bucket_id = 'match-covers');

drop policy if exists "storage_match_covers_insert" on storage.objects;
create policy "storage_match_covers_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_match_covers_update" on storage.objects;
create policy "storage_match_covers_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_match_covers_delete" on storage.objects;
create policy "storage_match_covers_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
