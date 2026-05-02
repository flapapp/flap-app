-- Required by public.enqueue_notification_backend (lookup by code).
-- Used when endorsing a profile badge (player_badge_endorsement_repository_impl).

insert into public.notification_types (code, label)
values ('badge_endorsed', 'Badge endorsed')
on conflict (code) do update set label = excluded.label;
