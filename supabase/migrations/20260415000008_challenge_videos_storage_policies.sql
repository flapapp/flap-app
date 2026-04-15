begin;

drop policy if exists "challenge_videos_select_public" on storage.objects;
drop policy if exists "challenge_videos_insert_own_folder" on storage.objects;
drop policy if exists "challenge_videos_update_own_folder" on storage.objects;
drop policy if exists "challenge_videos_delete_own_folder" on storage.objects;

create policy "challenge_videos_select_public"
on storage.objects
for select
to public
using ((bucket_id)::text = 'challenge_videos');

create policy "challenge_videos_insert_own_folder"
on storage.objects
for insert
to authenticated
with check (
  (bucket_id)::text = 'challenge_videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

create policy "challenge_videos_update_own_folder"
on storage.objects
for update
to authenticated
using (
  (bucket_id)::text = 'challenge_videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
)
with check (
  (bucket_id)::text = 'challenge_videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

create policy "challenge_videos_delete_own_folder"
on storage.objects
for delete
to authenticated
using (
  (bucket_id)::text = 'challenge_videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

commit;
