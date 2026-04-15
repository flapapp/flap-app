begin;

-- Reset storage.objects policies to avoid stale/recursive definitions
-- causing 42P17 during avatar upload.
drop policy if exists "public read avatars" on storage.objects;
drop policy if exists "Public read avatars" on storage.objects;
drop policy if exists "users upload own avatars" on storage.objects;
drop policy if exists "Users insert own avatar folder" on storage.objects;
drop policy if exists "users update own avatars" on storage.objects;
drop policy if exists "Users update own avatar folder" on storage.objects;
drop policy if exists "Users delete own avatar folder" on storage.objects;
drop policy if exists "users delete own avatars" on storage.objects;
drop policy if exists "avatars_select_public" on storage.objects;
drop policy if exists "avatars_insert_own_folder" on storage.objects;
drop policy if exists "avatars_update_own_folder" on storage.objects;
drop policy if exists "avatars_delete_own_folder" on storage.objects;
drop policy if exists "public read videos" on storage.objects;
drop policy if exists "users upload own videos and thumbnails" on storage.objects;

create policy "avatars_select_public"
on storage.objects for select
to public
using ((bucket_id)::text = 'avatars');

create policy "avatars_insert_own_folder"
on storage.objects for insert
to authenticated
with check (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
);

create policy "avatars_update_own_folder"
on storage.objects for update
to authenticated
using (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
)
with check (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
);

create policy "avatars_delete_own_folder"
on storage.objects for delete
to authenticated
using (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
);

create policy "public read videos"
on storage.objects
for select
using ((bucket_id)::text in ('videos', 'thumbnails', 'challenge_videos', 'team_logos'));

create policy "users upload own videos and thumbnails"
on storage.objects
for insert
to authenticated
with check (
  ((bucket_id)::text in ('videos', 'thumbnails', 'challenge_videos') and auth.uid()::text = split_part((name)::text, '/', 1))
  or (
    (bucket_id)::text = 'team_logos'
    and exists (
      select 1
      from public.teams t
      where t.id::text = split_part((name)::text, '/', 1)
        and t.owner_id = auth.uid()
    )
  )
);

commit;
