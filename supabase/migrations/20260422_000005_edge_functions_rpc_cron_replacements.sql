-- Replace Firebase Cloud Functions with Postgres-native RPC + cron helpers.
-- Push delivery is intentionally disabled in this migration window; queue rows
-- are marked as sent/cancelled by Edge worker without external dispatch.

create extension if not exists pg_cron;

create or replace function public.ensure_notification_type(p_code text, p_label text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id
  from public.notification_types
  where code = p_code
  limit 1;

  if v_id is null then
    insert into public.notification_types(code, label)
    values (p_code, p_label)
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

create or replace function public.accept_friend_request_rpc(
  p_request_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.friend_requests%rowtype;
  v_type_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.friend_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Friend request not found';
  end if;
  if v_req.to_user_id <> v_uid then
    raise exception 'Not your friend request';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'Friend request already processed';
  end if;

  update public.friend_requests
  set status = case when p_accept then 'accepted' else 'declined' end,
      responded_at = now()
  where id = v_req.id;

  if p_accept then
    insert into public.friendships(user_id, friend_user_id, source_request_id)
    values
      (v_req.from_user_id, v_req.to_user_id, v_req.id),
      (v_req.to_user_id, v_req.from_user_id, v_req.id)
    on conflict (user_id, friend_user_id) do nothing;

    v_type_id := public.ensure_notification_type(
      'friend_request_accepted',
      'Friend request accepted'
    );

    insert into public.notifications(
      user_id, notification_type_id, title, message, related_table, related_record_id
    )
    values (
      v_req.from_user_id,
      v_type_id,
      'Friend request accepted',
      'Your friend request was accepted.',
      'friend_requests',
      v_req.id
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'status', case when p_accept then 'accepted' else 'declined' end
  );
end;
$$;

create or replace function public.advance_challenge_statuses_rpc()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  update public.challenges
  set status = case
      when status = 'recruiting' and submission_deadline is not null and now() >= submission_deadline then 'submission'
      when status = 'submission' and voting_deadline is not null and now() >= voting_deadline then 'voting'
      when status = 'voting' and ends_at is not null and now() >= ends_at then 'completed'
      else status
    end,
    updated_at = now()
  where status in ('recruiting', 'submission', 'voting');

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.cleanup_old_notifications_rpc(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  delete from public.notifications
  where created_at <= now() - make_interval(days => p_days);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname in (
    'flap_advance_challenge_statuses',
    'flap_cleanup_old_notifications'
  );
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_advance_challenge_statuses',
  '0 * * * *',
  $$select public.advance_challenge_statuses_rpc();$$
);

select cron.schedule(
  'flap_cleanup_old_notifications',
  '15 3 * * *',
  $$select public.cleanup_old_notifications_rpc(30);$$
);
