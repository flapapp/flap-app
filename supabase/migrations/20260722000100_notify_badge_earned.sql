-- Badge-earned notifications.
--
-- The `badge_earned` notification type is fully handled by the notification-command
-- edge function but nothing ever emits it, so earning a badge is silent. Badges are
-- granted by inserting into public.user_badges; awardBadge() (source 'award') and any
-- future activity grants (source 'auto_activity') are true "you earned this" moments,
-- whereas source 'purchase' is a deliberate store buy that already has its own UI
-- feedback and is intentionally excluded here.
--
-- Mirrors notify_coins_earned: a trigger owns its own insert into notifications +
-- push_notification_queue (auth-independent, works for admin/system grants where
-- auth.uid() may be null), using the packed message format AppNotification expects.
-- Badge name/emoji come from the badges row in plain English, consistent with the
-- other server-emitted notifications (client localization isn't available in SQL).

create or replace function public.notify_badge_earned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_id uuid;
  v_name text;
  v_emoji text;
  v_label text;
  v_title constant text := 'New badge!';
  v_message text;
begin
  if new.source not in ('award', 'auto_activity') then
    return new;
  end if;

  select name, coalesce(emoji, '') into v_name, v_emoji
  from public.badges
  where id = new.badge_id;

  if v_name is null then
    return new;
  end if;

  v_label := btrim(v_emoji || ' ' || v_name);
  v_message := 'You earned the "' || v_label || '" badge!';

  v_type_id := public.ensure_notification_type('badge_earned', 'Badge earned');

  insert into public.notifications(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, is_read
  )
  values (
    new.user_id,
    v_type_id,
    v_title,
    jsonb_build_object(
      'v', 1,
      'displayMessage', v_message,
      'data', jsonb_build_object(
        'type', 'badge_earned',
        'badgeName', v_name,
        'badgeEmoji', v_emoji
      ),
      'actionUrl', '/profile',
      'imageUrl', null
    )::text,
    'badges',
    new.badge_id,
    false
  );

  insert into public.push_notification_queue(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, status
  )
  values (
    new.user_id, v_type_id, v_title, v_message,
    'badges', new.badge_id, 'pending'
  );

  return new;
end;
$$;

drop trigger if exists user_badges_notify_earned on public.user_badges;
create trigger user_badges_notify_earned
after insert on public.user_badges
for each row
execute function public.notify_badge_earned();
