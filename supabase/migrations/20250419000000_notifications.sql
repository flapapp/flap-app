-- In-app notifications + push queue (replaces Firestore `notifications` / `pushNotifications`).
-- FCM device tokens live on `profiles` (replaces Firestore `users` token fields).

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  type text not null,
  title text not null,
  message text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  is_read boolean not null default false,
  read_at timestamptz,
  image_url text,
  action_url text
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id)
  where is_read = false;

-- Processed by backend worker / Edge Function (replaces Firestore `pushNotifications`).
create table if not exists public.push_notification_queue (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists push_notification_queue_pending_idx
  on public.push_notification_queue (created_at)
  where processed_at is null;

alter table public.profiles add column if not exists fcm_token text;
alter table public.profiles add column if not exists fcm_token_updated_at timestamptz;
alter table public.profiles add column if not exists device_tokens text[] default '{}'::text[];

alter table public.notifications enable row level security;
alter table public.push_notification_queue enable row level security;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists notifications_insert_authenticated on public.notifications;
create policy notifications_insert_authenticated
  on public.notifications for insert
  to authenticated
  with check (true);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
  on public.notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
  on public.notifications for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists push_queue_insert_authenticated on public.push_notification_queue;
create policy push_queue_insert_authenticated
  on public.push_notification_queue for insert
  to authenticated
  with check (true);

drop policy if exists push_queue_no_select on public.push_notification_queue;
create policy push_queue_no_select
  on public.push_notification_queue for select
  to authenticated
  using (false);

-- Enable Realtime for `public.notifications` in Supabase Dashboard (Database → Replication)
-- or: alter publication supabase_realtime add table public.notifications;
