-- Carry notification payload into push queue so FCM can include granular routing (e.g. data.type under match_invite).

alter table public.push_notification_queue
  add column if not exists extra_data jsonb not null default '{}'::jsonb;

create or replace function public.enqueue_notification_backend(
  p_target_user_id uuid,
  p_type_code text,
  p_title text,
  p_message text,
  p_data jsonb default '{}'::jsonb,
  p_related_table text default null,
  p_related_record_id uuid default null,
  p_action_url text default null,
  p_image_url text default null,
  p_idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_id uuid;
  v_notification_id uuid;
  v_key text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select id into v_type_id
  from public.notification_types
  where code = p_type_code
  limit 1;

  if v_type_id is null then
    raise exception 'Unknown notification type: %', p_type_code;
  end if;

  v_key := coalesce(p_idempotency_key, auth.uid()::text || ':' || p_target_user_id::text || ':' || p_type_code || ':' || extract(epoch from now())::bigint::text);

  begin
    insert into public.notification_dispatch_log(
      idempotency_key, requested_by, target_user_id, type_code, status
    ) values (
      v_key, auth.uid(), p_target_user_id, p_type_code, 'processing'
    );
  exception when unique_violation then
    return null;
  end;

  insert into public.notifications(
    user_id,
    notification_type_id,
    title,
    message,
    related_table,
    related_record_id,
    is_read
  ) values (
    p_target_user_id,
    v_type_id,
    p_title,
    jsonb_build_object(
      'v', 1,
      'displayMessage', p_message,
      'data', coalesce(p_data, '{}'::jsonb),
      'actionUrl', p_action_url,
      'imageUrl', p_image_url
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
    extra_data,
    status
  ) values (
    p_target_user_id,
    v_type_id,
    p_title,
    p_message,
    p_related_table,
    p_related_record_id,
    coalesce(p_data, '{}'::jsonb),
    'pending'
  );

  update public.notification_dispatch_log
  set status = 'created',
      notification_id = v_notification_id,
      processed_at = timezone('utc', now())
  where idempotency_key = v_key;

  return v_notification_id;
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
    extra_data,
    status
  ) values (
    p_user_id,
    v_type_id,
    p_title,
    p_message,
    p_related_table,
    p_related_record_id,
    coalesce(p_payload, '{}'::jsonb),
    'pending'
  );

  update public.notification_dispatch_log
  set status = 'created',
      notification_id = v_notification_id,
      processed_at = timezone('utc', now())
  where idempotency_key = v_key;
end;
$$;
