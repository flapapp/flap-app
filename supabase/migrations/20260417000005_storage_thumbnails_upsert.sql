-- Thumbnail uploads use `upsert: true` (INSERT or UPDATE). Prior migrations only allowed INSERT.

begin;

create policy "thumbnails_update_own_folder"
on storage.objects
for update
to authenticated
using (
  (bucket_id)::text = 'thumbnails'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
)
with check (
  (bucket_id)::text = 'thumbnails'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

create policy "thumbnails_delete_own_folder"
on storage.objects
for delete
to authenticated
using (
  (bucket_id)::text = 'thumbnails'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

commit;
