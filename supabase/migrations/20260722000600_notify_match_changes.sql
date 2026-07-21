-- Match lifecycle notifications (checklist items 13-16).
--
-- 13. Match cancelled   — trigger, on status -> cancelled
-- 15. Match details changed — trigger, on scheduled_at/location/city change
-- 16. Match roster full  — trigger, on status -> full
-- 14. Match reminder     — cron, matches starting within the next 24h
--
-- All delivered through enqueue_notification_system (auth-independent + deduped
-- by idempotency key), so they work from the cron/owner context and never
-- double-fire. Recipients are the accepted players, pending applicants, and
-- pending invitees as appropriate; the organizer who made the change is excluded
-- from change notifications but IS reminded/told when the match fills.

-- ---------------------------------------------------------------------------
-- Items 13, 15, 16: react to match row changes.
-- ---------------------------------------------------------------------------
create or replace function public.notify_match_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action_url text := '/match-details/' || new.id::text;
  v_title text := coalesce(nullif(btrim(new.title), ''), 'your match');
  v_recipient record;
begin
  -- Item 13: cancellation. Tell everyone who was in or waiting on the match.
  if new.status = 'cancelled' and old.status is distinct from 'cancelled' then
    for v_recipient in
      select user_id from public.match_participants
        where match_id = new.id and status in ('accepted', 'pending_application')
      union
      select user_id from public.match_invites
        where match_id = new.id and status = 'pending'
    loop
      if v_recipient.user_id <> new.organizer_id then
        perform public.enqueue_notification_system(
          v_recipient.user_id, 'match_cancelled', 'Match cancelled',
          format('"%s" has been cancelled.', v_title),
          jsonb_build_object('type', 'match_cancelled', 'matchId', new.id::text),
          v_action_url, 'matches', new.id,
          'match_cancelled:' || new.id::text || ':' || v_recipient.user_id::text
        );
      end if;
    end loop;
    -- A cancelled match shouldn't also emit "full"/"details changed".
    return new;
  end if;

  -- Item 16: match filled up.
  if new.status = 'full' and old.status is distinct from 'full' then
    perform public.enqueue_notification_system(
      new.organizer_id, 'match_full', 'Match is full',
      format('Your match "%s" is full and ready to go!', v_title),
      jsonb_build_object('type', 'match_full', 'matchId', new.id::text),
      v_action_url, 'matches', new.id,
      'match_full_org:' || new.id::text
    );
    for v_recipient in
      select user_id from public.match_participants
        where match_id = new.id and status = 'accepted'
    loop
      if v_recipient.user_id <> new.organizer_id then
        perform public.enqueue_notification_system(
          v_recipient.user_id, 'match_full', 'Match is full',
          format('"%s" is full — see you on the pitch!', v_title),
          jsonb_build_object('type', 'match_full', 'matchId', new.id::text),
          v_action_url, 'matches', new.id,
          'match_full:' || new.id::text || ':' || v_recipient.user_id::text
        );
      end if;
    end loop;
  end if;

  -- Item 15: time / location changed on a still-live match. The idempotency key
  -- carries updated_at so each distinct edit notifies once (and only once).
  if new.status in ('open', 'full')
     and (new.scheduled_at is distinct from old.scheduled_at
          or new.location is distinct from old.location
          or new.city is distinct from old.city) then
    for v_recipient in
      select user_id from public.match_participants
        where match_id = new.id and status in ('accepted', 'pending_application')
      union
      select user_id from public.match_invites
        where match_id = new.id and status = 'pending'
    loop
      if v_recipient.user_id <> new.organizer_id then
        perform public.enqueue_notification_system(
          v_recipient.user_id, 'match_updated', 'Match details changed',
          format('Details for "%s" changed — check the latest time and location.', v_title),
          jsonb_build_object('type', 'match_updated', 'matchId', new.id::text),
          v_action_url, 'matches', new.id,
          'match_updated:' || new.id::text || ':' || v_recipient.user_id::text
            || ':' || extract(epoch from new.updated_at)::bigint::text
        );
      end if;
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists matches_notify_changes on public.matches;
create trigger matches_notify_changes
after update on public.matches
for each row
execute function public.notify_match_changes();

-- ---------------------------------------------------------------------------
-- Item 14: remind the organizer + accepted players about matches starting in
-- the next 24h. Once per match/user (idempotency key), independent of clients.
-- ---------------------------------------------------------------------------
create or replace function public.notify_matches_starting_soon()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match record;
  v_recipient record;
  v_count integer := 0;
  v_hours integer;
  v_when text;
  v_title text;
begin
  for v_match in
    select id, title, organizer_id, scheduled_at
    from public.matches
    where status in ('open', 'full')
      and scheduled_at is not null
      and scheduled_at > now()
      and scheduled_at <= now() + interval '24 hours'
  loop
    v_hours := greatest(1, floor(extract(epoch from (v_match.scheduled_at - now())) / 3600.0)::int);
    v_when := case when v_hours <= 1 then 'starting soon' else format('in about %s hours', v_hours) end;
    v_title := coalesce(nullif(btrim(v_match.title), ''), 'your match');

    for v_recipient in
      select v_match.organizer_id as user_id
      union
      select user_id from public.match_participants
        where match_id = v_match.id and status = 'accepted'
    loop
      if public.enqueue_notification_system(
        v_recipient.user_id, 'match_reminder', 'Match reminder',
        format('"%s" is %s.', v_title, v_when),
        jsonb_build_object('type', 'match_reminder', 'matchId', v_match.id::text),
        '/match-details/' || v_match.id::text, 'matches', v_match.id,
        'match_reminder:' || v_match.id::text || ':' || v_recipient.user_id::text
      ) is not null then
        v_count := v_count + 1;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'flap_notify_matches_starting_soon';
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_notify_matches_starting_soon',
  '*/30 * * * *',
  $$select public.notify_matches_starting_soon();$$
);
