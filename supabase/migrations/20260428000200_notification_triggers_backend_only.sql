create or replace function public._notification_type_id(p_code text, p_label text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id from public.notification_types where code = p_code limit 1;
  if v_id is not null then
    return v_id;
  end if;
  insert into public.notification_types(code, label)
  values (p_code, p_label)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public._create_and_queue_notification(
  p_user_id uuid,
  p_type_code text,
  p_type_label text,
  p_title text,
  p_message text,
  p_payload jsonb default '{}'::jsonb,
  p_related_table text default null,
  p_related_record_id uuid default null,
  p_action_url text default null,
  p_idempotency_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_id uuid;
  v_notification_id uuid;
  v_key text;
begin
  if p_user_id is null then
    return;
  end if;

  v_key := coalesce(
    p_idempotency_key,
    p_type_code || ':' || p_user_id::text || ':' || extract(epoch from timezone('utc', now()))::bigint::text
  );

  begin
    insert into public.notification_dispatch_log(
      idempotency_key,
      requested_by,
      target_user_id,
      type_code,
      status
    ) values (
      v_key,
      coalesce(auth.uid(), p_user_id),
      p_user_id,
      p_type_code,
      'processing'
    );
  exception when unique_violation then
    return;
  end;

  v_type_id := public._notification_type_id(p_type_code, p_type_label);

  insert into public.notifications(
    user_id,
    notification_type_id,
    title,
    message,
    related_table,
    related_record_id,
    is_read
  ) values (
    p_user_id,
    v_type_id,
    p_title,
    jsonb_build_object(
      'v', 1,
      'displayMessage', p_message,
      'data', coalesce(p_payload, '{}'::jsonb),
      'actionUrl', p_action_url,
      'imageUrl', null
    )::text,
    p_related_table,
    p_related_record_id,
    false
  ) returning id into v_notification_id;

  insert into public.push_notification_queue(
    user_id,
    notification_type_id,
    title,
    message,
    related_table,
    related_record_id,
    status
  ) values (
    p_user_id,
    v_type_id,
    p_title,
    p_message,
    p_related_table,
    p_related_record_id,
    'pending'
  );

  update public.notification_dispatch_log
  set status = 'created',
      notification_id = v_notification_id,
      processed_at = timezone('utc', now())
  where idempotency_key = v_key;
end;
$$;

create or replace function public.notify_on_friend_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  select coalesce(display_name, nickname, first_name || ' ' || last_name, 'A player')
    into v_name
  from public.profiles
  where id = new.from_user_id;

  perform public._create_and_queue_notification(
    new.to_user_id,
    'friend_request',
    'Friend request',
    'Friend request',
    coalesce(v_name, 'A player') || ' sent you a friend request',
    jsonb_build_object('type', 'friend_request', 'requestId', new.id),
    null,
    null,
    '/friends',
    'friend_request:' || new.id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_friend_request_insert on public.friend_requests;
create trigger trg_notify_friend_request_insert
after insert on public.friend_requests
for each row execute function public.notify_on_friend_request_insert();

create or replace function public.notify_on_match_invite_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status <> 'pending' then
    return new;
  end if;
  perform public._create_and_queue_notification(
    new.user_id,
    'match_invite',
    'Match invite',
    'Match invite',
    'You have been invited to a match',
    jsonb_build_object('type', 'match_invite', 'matchId', new.match_id),
    'matches',
    new.match_id,
    null,
    'match_invite:' || new.match_id::text || ':' || new.user_id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_match_invite_insert on public.match_invites;
create trigger trg_notify_match_invite_insert
after insert on public.match_invites
for each row execute function public.notify_on_match_invite_insert();

create or replace function public.notify_on_match_participant_status_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_organizer uuid;
begin
  if tg_op = 'INSERT' and new.status = 'pending_application' then
    select organizer_id into v_organizer from public.matches where id = new.match_id;
    perform public._create_and_queue_notification(
      v_organizer,
      'match_invite',
      'Match update',
      'Match application',
      'A player applied to join your match',
      jsonb_build_object('type', 'match_application_submitted', 'matchId', new.match_id),
      'matches',
      new.match_id,
      null,
      'match_apply:' || new.match_id::text || ':' || new.user_id::text
    );
  elsif tg_op = 'UPDATE' and old.status is distinct from new.status and new.status in ('accepted','rejected') then
    perform public._create_and_queue_notification(
      new.user_id,
      'match_invite',
      'Match update',
      case when new.status = 'accepted' then 'Application accepted' else 'Application rejected' end,
      case when new.status = 'accepted' then 'Your match application was accepted' else 'Your match application was rejected' end,
      jsonb_build_object('type', 'match_application_' || new.status, 'matchId', new.match_id),
      'matches',
      new.match_id,
      null,
      'match_apply_result:' || new.match_id::text || ':' || new.user_id::text || ':' || new.status
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_match_participant_insert on public.match_participants;
create trigger trg_notify_match_participant_insert
after insert on public.match_participants
for each row execute function public.notify_on_match_participant_status_update();

drop trigger if exists trg_notify_match_participant_update on public.match_participants;
create trigger trg_notify_match_participant_update
after update on public.match_participants
for each row execute function public.notify_on_match_participant_status_update();

create or replace function public.notify_on_team_invite_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_name text;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  select name into v_team_name from public.teams where id = new.team_id;
  perform public._create_and_queue_notification(
    new.user_id,
    'team_invite',
    'Team invite',
    'Team invite',
    'You were invited to join "' || coalesce(v_team_name, 'a team') || '"',
    jsonb_build_object('type', 'team_invite', 'teamId', new.team_id),
    'teams',
    new.team_id,
    '/profile',
    'team_invite:' || new.team_id::text || ':' || new.user_id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_team_invite_insert on public.team_invites;
create trigger trg_notify_team_invite_insert
after insert on public.team_invites
for each row execute function public.notify_on_team_invite_insert();

create or replace function public.notify_on_team_join_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_name text;
  v_requester text;
  r record;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  select name into v_team_name from public.teams where id = new.team_id;
  select coalesce(display_name, nickname, first_name || ' ' || last_name, 'A player')
    into v_requester
  from public.profiles
  where id = new.user_id;

  for r in
    select user_id
    from public.team_members
    where team_id = new.team_id
      and role in ('captain', 'vice_captain')
  loop
    if r.user_id <> new.user_id then
      perform public._create_and_queue_notification(
        r.user_id,
        'team_join_request',
        'Team join request',
        'Team join request',
        coalesce(v_requester, 'A player') || ' wants to join "' || coalesce(v_team_name, 'your team') || '"',
        jsonb_build_object('type', 'team_join_request', 'teamId', new.team_id, 'requestId', new.id),
        'teams',
        new.team_id,
        null,
        'team_join_req:' || new.id::text || ':' || r.user_id::text
      );
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_notify_team_join_request_insert on public.team_join_requests;
create trigger trg_notify_team_join_request_insert
after insert on public.team_join_requests
for each row execute function public.notify_on_team_join_request_insert();

create or replace function public.notify_on_team_match_request_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_opponent text;
  r record;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  select name into v_opponent from public.teams where id = new.target_team_id;

  for r in
    select user_id
    from public.team_members
    where team_id = new.requesting_team_id
      and role in ('captain', 'vice_captain')
  loop
    perform public._create_and_queue_notification(
      r.user_id,
      'team_match_request',
      'Team match request',
      'Team match request',
      'Team "' || coalesce(v_opponent, 'opponent') || '" requested a match',
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

drop trigger if exists trg_notify_team_match_request_insert on public.team_match_requests;
create trigger trg_notify_team_match_request_insert
after insert on public.team_match_requests
for each row execute function public.notify_on_team_match_request_insert();

create or replace function public.notify_on_match_roster_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_id uuid;
  v_team_name text;
begin
  if new.status <> 'pending' then
    return new;
  end if;
  select mt.match_id, coalesce(mt.display_name, 'Team') into v_match_id, v_team_name
  from public.match_teams mt
  where mt.id = new.match_team_id;
  if v_match_id is null then
    return new;
  end if;
  perform public._create_and_queue_notification(
    new.player_id,
    'team_roster_invite',
    'Roster invite',
    'Roster invite',
    'You were invited to roster for "' || v_team_name || '"',
    jsonb_build_object('type', 'team_roster_invite', 'matchId', v_match_id),
    'matches',
    v_match_id,
    null,
    'team_roster:' || new.match_team_id::text || ':' || new.player_id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_match_roster_insert on public.match_team_rosters;
create trigger trg_notify_match_roster_insert
after insert on public.match_team_rosters
for each row execute function public.notify_on_match_roster_insert();

create or replace function public.notify_on_challenge_submission_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_creator uuid;
  v_title text;
  v_participant text;
begin
  select creator_id, title into v_creator, v_title
  from public.challenges
  where id = new.challenge_id;
  if v_creator is null or v_creator = new.user_id then
    return new;
  end if;
  select coalesce(display_name, nickname, first_name || ' ' || last_name, 'A player')
    into v_participant
  from public.profiles
  where id = new.user_id;

  perform public._create_and_queue_notification(
    v_creator,
    'challenge_update',
    'Challenge update',
    'Challenge update',
    coalesce(v_participant, 'A player') || ' uploaded a video to "' || coalesce(v_title, 'challenge') || '"',
    jsonb_build_object('type', 'challenge_update', 'challengeId', new.challenge_id),
    'challenges',
    new.challenge_id,
    null,
    'challenge_submission:' || new.challenge_id::text || ':' || new.user_id::text
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_challenge_submission_insert on public.challenge_submissions;
create trigger trg_notify_challenge_submission_insert
after insert on public.challenge_submissions
for each row execute function public.notify_on_challenge_submission_insert();

create or replace function public.notify_on_match_finished_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  if old.status is not distinct from new.status or new.status <> 'finished' then
    return new;
  end if;

  for r in
    select user_id
    from public.match_participants
    where match_id = new.id
      and status = 'accepted'
  loop
    perform public._create_and_queue_notification(
      r.user_id,
      'match_finished',
      'Match finished',
      'Match finished',
      'The match has finished. Please rate the players.',
      jsonb_build_object('type', 'match_finished', 'matchId', new.id),
      'matches',
      new.id,
      '/match/' || new.id::text || '/rate',
      'match_finished:' || new.id::text || ':' || r.user_id::text
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists trg_notify_match_finished_update on public.matches;
create trigger trg_notify_match_finished_update
after update on public.matches
for each row execute function public.notify_on_match_finished_update();
