begin;

-- Migration 20260415000004 reset storage to avatars-only, which removed INSERT/SELECT for
-- `team_logos` and other media buckets. That breaks team logo upload (StorageException 403).
-- Restore bucket visibility, public object reads, and owner-scoped writes for team_logos
-- (path: `{team_uuid}/...`, matches SupabaseTeamLogoStorage). Include videos/thumbnails
-- insert rules aligned with earlier migrations.

-- Authenticated clients need to read bucket rows for uploads (Storage API checks).
create policy "buckets_auth_read_media_buckets"
on storage.buckets
for select
to authenticated
using (
  (id)::text in ('videos', 'thumbnails', 'challenge_videos', 'team_logos')
);

-- Public URLs for team crests and video assets.
create policy "objects_public_read_videos_thumbnails_team_logos"
on storage.objects
for select
to public
using ((bucket_id)::text in ('videos', 'thumbnails', 'team_logos'));

-- User-folder uploads for videos + thumbnails; challenge_videos path prefix = auth uid;
-- team_logos: first path segment = team id and caller owns the team in public.teams.
create policy "objects_insert_videos_thumbnails_challenge_team_logos"
on storage.objects
for insert
to authenticated
with check (
  auth.uid() is not null
  and (
    (
      (bucket_id)::text in ('videos', 'thumbnails', 'challenge_videos')
      and split_part((name)::text, '/', 1) = auth.uid()::text
    )
    or (
      (bucket_id)::text = 'team_logos'
      and exists (
        select 1
        from public.teams t
        where t.id::text = split_part((name)::text, '/', 1)
          and t.owner_id = auth.uid()
          and t.deleted_at is null
      )
    )
  )
);

-- Team logo upload uses upsert:true — requires UPDATE when object already exists.
create policy "team_logos_update_owner_folder"
on storage.objects
for update
to authenticated
using (
  (bucket_id)::text = 'team_logos'
  and auth.uid() is not null
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part((name)::text, '/', 1)
      and t.owner_id = auth.uid()
      and t.deleted_at is null
  )
)
with check (
  (bucket_id)::text = 'team_logos'
  and auth.uid() is not null
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part((name)::text, '/', 1)
      and t.owner_id = auth.uid()
      and t.deleted_at is null
  )
);

create policy "team_logos_delete_owner_folder"
on storage.objects
for delete
to authenticated
using (
  (bucket_id)::text = 'team_logos'
  and auth.uid() is not null
  and exists (
    select 1
    from public.teams t
    where t.id::text = split_part((name)::text, '/', 1)
      and t.owner_id = auth.uid()
      and t.deleted_at is null
  )
);

commit;
