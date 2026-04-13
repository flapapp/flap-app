-- Team logo storage policies referenced `public.teams` inside RLS; that subquery
-- runs as the invoker and can fail (403) if table privileges / RLS evaluation
-- does not see the new row. Use a SECURITY DEFINER helper so the manager check
-- is reliable while still binding to auth.uid().

create or replace function public.user_manages_team_for_storage_path(p_object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_team_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null or p_object_name is null or position('/' in p_object_name) = 0 then
    return false;
  end if;

  begin
    v_team_id := split_part(p_object_name, '/', 1)::uuid;
  exception
    when invalid_text_representation then
      return false;
  end;

  return exists (
    select 1
    from public.teams t
    where t.id = v_team_id
      and (
        t.captain_id = v_uid
        or v_uid = any (t.vice_captain_ids)
      )
  );
end;
$$;

comment on function public.user_manages_team_for_storage_path(text) is
  'Used by storage.objects RLS for team-logos; definer reads teams for EXISTS while enforcing auth.uid().';

grant execute on function public.user_manages_team_for_storage_path(text) to authenticated;

grant select, update on table public.teams to authenticated;

drop policy if exists "Managers insert team logo" on storage.objects;
create policy "Managers insert team logo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'team-logos'
    and public.user_manages_team_for_storage_path(name)
  );

drop policy if exists "Managers update team logo" on storage.objects;
create policy "Managers update team logo"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'team-logos'
    and public.user_manages_team_for_storage_path(name)
  );

drop policy if exists "Managers delete team logo" on storage.objects;
create policy "Managers delete team logo"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'team-logos'
    and public.user_manages_team_for_storage_path(name)
  );
