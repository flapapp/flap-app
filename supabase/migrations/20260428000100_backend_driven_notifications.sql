create table if not exists public.notification_dispatch_log (
  id uuid primary key default gen_random_uuid(),
  idempotency_key text not null unique,
  requested_by uuid not null references auth.users(id) on delete cascade,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  type_code text not null,
  notification_id uuid references public.notifications(id) on delete set null,
  status text not null default 'processing',
  error_message text,
  processed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.notification_dispatch_log enable row level security;

drop policy if exists "dispatch_log_owner_select" on public.notification_dispatch_log;
create policy "dispatch_log_owner_select"
on public.notification_dispatch_log
for select
to authenticated
using (requested_by = auth.uid());

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
    status
  ) values (
    p_target_user_id,
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

  return v_notification_id;
end;
$$;

revoke all on function public.enqueue_notification_backend(
  uuid, text, text, text, jsonb, text, uuid, text, text, text
) from public;
grant execute on function public.enqueue_notification_backend(
  uuid, text, text, text, jsonb, text, uuid, text, text, text
) to authenticated;
