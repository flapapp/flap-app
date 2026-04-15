begin;

-- Hard reset policies on storage.objects and storage.buckets to
-- minimal non-recursive rules for avatar uploads.
do $$
declare
  _policy_name text;
begin
  for _policy_name in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
  loop
    execute format('drop policy if exists %I on storage.objects', _policy_name);
  end loop;

  for _policy_name in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'buckets'
  loop
    execute format('drop policy if exists %I on storage.buckets', _policy_name);
  end loop;
end $$;

-- Buckets visibility for storage API checks.
create policy "buckets_public_read_avatars"
on storage.buckets
for select
to public
using ((id)::text = 'avatars');

create policy "buckets_auth_read_avatars"
on storage.buckets
for select
to authenticated
using ((id)::text = 'avatars');

-- Objects policies for avatar CRUD.
create policy "objects_public_read_avatars"
on storage.objects
for select
to public
using ((bucket_id)::text = 'avatars');

create policy "objects_auth_insert_avatars_own_folder"
on storage.objects
for insert
to authenticated
with check (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

create policy "objects_auth_update_avatars_own_folder"
on storage.objects
for update
to authenticated
using (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
)
with check (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

create policy "objects_auth_delete_avatars_own_folder"
on storage.objects
for delete
to authenticated
using (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and split_part((name)::text, '/', 1) = auth.uid()::text
);

commit;
