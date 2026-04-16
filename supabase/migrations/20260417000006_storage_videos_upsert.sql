-- Library video uploads use `upsert: true` on the `videos` bucket (see SupabaseVideosRemoteDataSource).

begin;

create policy "videos_update_own_folder"
on storage.objects
for update
to authenticated
using (
  (bucket_id)::text = 'videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
)
with check (
  (bucket_id)::text = 'videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

create policy "videos_delete_own_folder"
on storage.objects
for delete
to authenticated
using (
  (bucket_id)::text = 'videos'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

commit;
