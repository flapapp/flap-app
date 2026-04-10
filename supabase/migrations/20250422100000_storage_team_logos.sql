-- Public bucket for club crests at path: {team_id}/logo.png
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'team-logos',
  'team-logos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public read team logos" on storage.objects;
create policy "Public read team logos"
  on storage.objects for select
  using (bucket_id = 'team-logos');

drop policy if exists "Managers insert team logo" on storage.objects;
create policy "Managers insert team logo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'team-logos'
    and exists (
      select 1 from public.teams t
      where t.id::text = split_part(name, '/', 1)
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );

drop policy if exists "Managers update team logo" on storage.objects;
create policy "Managers update team logo"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'team-logos'
    and exists (
      select 1 from public.teams t
      where t.id::text = split_part(name, '/', 1)
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );

drop policy if exists "Managers delete team logo" on storage.objects;
create policy "Managers delete team logo"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'team-logos'
    and exists (
      select 1 from public.teams t
      where t.id::text = split_part(name, '/', 1)
        and (
          t.captain_id = auth.uid()
          or auth.uid() = any (t.vice_captain_ids)
        )
    )
  );
