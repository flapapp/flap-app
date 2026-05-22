-- Privacy toggles referenced in app settings UI.
alter table public.user_settings
  add column if not exists show_online_status boolean not null default true,
  add column if not exists allow_friend_requests boolean not null default true;
