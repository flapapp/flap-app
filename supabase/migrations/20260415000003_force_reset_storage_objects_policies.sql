begin;

-- Force-reset all policies on storage.objects.
-- This removes unknown/legacy policies that can still cause 42P17.
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
end $$;

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
