-- Notify target team captains/vice-captains when another team requests a match (was reversed).
-- Allow match organizers to create team_match_requests and roster rows for their match.

create or replace function public.notify_on_team_match_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_requesting_name text;
  r record;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  select name into v_requesting_name from public.teams where id = new.requesting_team_id;

  for r in
    select user_id
    from public.team_members
    where team_id = new.target_team_id
      and role in ('captain', 'vice_captain')
  loop
    perform public._create_and_queue_notification(
      r.user_id,
      'team_match_request',
      'Team match request',
      'Team match request',
      'Team "' || coalesce(v_requesting_name, 'Team') || '" invited your team to a match',
      jsonb_build_object('type', 'team_match_request', 'matchId', new.match_id),
      'matches',
      new.match_id,
      null,
      'team_match_req:' || new.id::text || ':' || r.user_id::text
    );
  end loop;
  return new;
end;
$$;

create policy team_match_requests_insert_match_organizer
  on public.team_match_requests for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.organizer_id = (select auth.uid())
        and m.is_team_match is true
    )
  );

create policy team_match_request_players_mutate_match_organizer
  on public.team_match_request_players for all
  to authenticated
  using (
    exists (
      select 1 from public.team_match_requests tmr
      join public.matches m on m.id = tmr.match_id
      where tmr.id = team_match_request_players.team_match_request_id
        and m.organizer_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.team_match_requests tmr
      join public.matches m on m.id = tmr.match_id
      where tmr.id = team_match_request_players.team_match_request_id
        and m.organizer_id = (select auth.uid())
    )
  );
