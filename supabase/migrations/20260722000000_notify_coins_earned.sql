-- Coins-earned notifications.
--
-- Coins are credited from several contexts that share no common auth identity:
--   * challenge prize distribution (_finalize_challenge, run by pg_cron, no auth.uid())
--   * FL Coin purchases (Paddle webhook, service role, no auth.uid())
--   * signup bonus (auth-user bootstrap trigger)
--   * client-side grants (voting reward, refunds, ...)
-- The one thing they all share is an INSERT into public.coin_transactions, so a
-- trigger there is the single chokepoint that guarantees every credit notifies
-- the recipient exactly once. We cannot reuse enqueue_notification_backend here
-- because it requires auth.uid() (null under cron / service role), so this owns
-- its own insert into notifications + push_notification_queue, matching the same
-- packed message format (v:1) that AppNotification.fromSupabase expects.
--
-- Only positive amounts notify: spends are stored as negative amounts (balance is
-- a running sum(amount)), and the badge_awarded ledger row is amount 0 (badges get
-- their own notification), so `amount > 0` cleanly isolates real credits.

create or replace function public.notify_coins_earned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_id uuid;
  v_reason text;
  v_title constant text := 'Coins earned!';
  v_message text;
begin
  if new.amount is null or new.amount <= 0 then
    return new;
  end if;

  v_type_id := public.ensure_notification_type('coins_earned', 'Coins earned');

  v_reason := nullif(btrim(coalesce(new.description, '')), '');
  v_message := case
    when v_reason is null then 'You earned ' || new.amount || ' coins.'
    else 'You earned ' || new.amount || ' coins for ' || v_reason || '.'
  end;

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
        'type', 'coins_earned',
        'amount', new.amount,
        'reason', coalesce(v_reason, '')
      ),
      'actionUrl', '/profile',
      'imageUrl', null
    )::text,
    'coin_transactions',
    new.id,
    false
  );

  insert into public.push_notification_queue(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, status
  )
  values (
    new.user_id, v_type_id, v_title, v_message,
    'coin_transactions', new.id, 'pending'
  );

  return new;
end;
$$;

drop trigger if exists coin_transactions_notify_earned on public.coin_transactions;
create trigger coin_transactions_notify_earned
after insert on public.coin_transactions
for each row
execute function public.notify_coins_earned();
