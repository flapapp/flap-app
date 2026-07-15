-- Post-match photos: each participant can upload one or more photos after a
-- game, forming a shared memory of the match. Photos are shown on the match
-- details page to everyone who can view the match.
--
-- Storage: image bytes live in the public `match-photos` bucket under a
-- `<uploader_uid>/<match_id>/<file>` prefix (user-owned prefix, matching the
-- other media buckets). This table holds one row per photo with the public URL.

-- =============================================================================
-- Table
-- =============================================================================
create table if not exists public.match_photos (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  uploader_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists match_photos_match_id_created_idx
  on public.match_photos (match_id, created_at desc);

alter table public.match_photos enable row level security;

-- Anyone who can see the match can see its photos (participants, invitees,
-- organizer, team-roster members, or anyone for public matches).
drop policy if exists match_photos_select_if_match_visible on public.match_photos;
create policy match_photos_select_if_match_visible
  on public.match_photos for select
  to authenticated
  using (public.can_view_match(match_id, (select auth.uid())));

-- Only actual participants of the match may add photos, and only as themselves.
drop policy if exists match_photos_insert_participant on public.match_photos;
create policy match_photos_insert_participant
  on public.match_photos for insert
  to authenticated
  with check (
    uploader_id = (select auth.uid())
    and (
      exists (
        select 1 from public.matches m
        where m.id = match_id and m.organizer_id = (select auth.uid())
      )
      or exists (
        select 1 from public.match_participants mp
        where mp.match_id = match_id
          and mp.user_id = (select auth.uid())
          and mp.status = 'accepted'
      )
      or public.user_participates_via_team_roster(match_id, (select auth.uid()))
    )
  );

-- A photo can be removed by its uploader, the match organizer, or an admin.
drop policy if exists match_photos_delete_owner_or_organizer on public.match_photos;
create policy match_photos_delete_owner_or_organizer
  on public.match_photos for delete
  to authenticated
  using (
    uploader_id = (select auth.uid())
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- =============================================================================
-- Storage bucket + object policies (public read, user-scoped writes)
-- =============================================================================
insert into storage.buckets (id, name, public)
values ('match-photos', 'match-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "storage_match_photos_select" on storage.objects;
create policy "storage_match_photos_select"
  on storage.objects for select
  to public
  using (bucket_id = 'match-photos');

drop policy if exists "storage_match_photos_insert" on storage.objects;
create policy "storage_match_photos_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'match-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_match_photos_update" on storage.objects;
create policy "storage_match_photos_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'match-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'match-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_match_photos_delete" on storage.objects;
create policy "storage_match_photos_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'match-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- =============================================================================
-- Realtime: the gallery streams this table so photos appear live for everyone
-- viewing the match as participants add them.
-- =============================================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'match_photos'
  ) then
    alter publication supabase_realtime add table public.match_photos;
  end if;
end $$;

alter table public.match_photos replica identity full;
