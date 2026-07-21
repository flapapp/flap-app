-- Subscription/billing + coin-purchase notifications (checklist items 7-12).
--
-- The Paddle webhook runs with the service role and has no auth.uid(), so it
-- cannot use enqueue_notification_backend (which requires an authenticated
-- caller). enqueue_notification_system is the auth-independent equivalent: a
-- SECURITY DEFINER RPC the webhook (and cron) call to deliver a notification +
-- push to a user, deduplicated by idempotency key. It powers:
--   7. premium_activated        (webhook: first grant of access)
--   9. subscription_renewed      (webhook: recurring transaction.completed)
--   10. payment_failed           (webhook: transaction.payment_failed)
--   11. subscription_cancelled / _expired (webhook: status transitions)
--   8. trial_ending              (cron: notify_trial_ending, below)
-- Item 12 (coin purchase confirmation) is handled at the coin_transactions
-- chokepoint by giving coin_purchase credits their own wording (see below), so
-- it stays a single notification rather than a second one from the webhook.

-- ---------------------------------------------------------------------------
-- System notification enqueue (no authenticated caller required).
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_notification_system(
  p_target_user_id uuid,
  p_type_code text,
  p_title text,
  p_message text,
  p_data jsonb default '{}'::jsonb,
  p_action_url text default null,
  p_related_table text default null,
  p_related_record_id uuid default null,
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
  if p_target_user_id is null then
    return null;
  end if;

  v_type_id := public.ensure_notification_type(p_type_code, p_type_code);

  v_key := coalesce(
    p_idempotency_key,
    'system:' || p_target_user_id::text || ':' || p_type_code || ':' ||
      extract(epoch from now())::bigint::text
  );

  -- Dedup: the recipient doubles as requested_by so the FK to auth.users holds
  -- in a caller-less (cron / service role) context.
  begin
    insert into public.notification_dispatch_log(
      idempotency_key, requested_by, target_user_id, type_code, status
    ) values (
      v_key, p_target_user_id, p_target_user_id, p_type_code, 'processing'
    );
  exception when unique_violation then
    return null;
  end;

  insert into public.notifications(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, is_read
  ) values (
    p_target_user_id,
    v_type_id,
    p_title,
    jsonb_build_object(
      'v', 1,
      'displayMessage', p_message,
      'data', coalesce(p_data, '{}'::jsonb),
      'actionUrl', p_action_url,
      'imageUrl', null
    )::text,
    p_related_table,
    p_related_record_id,
    false
  ) returning id into v_notification_id;

  insert into public.push_notification_queue(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, status
  ) values (
    p_target_user_id, v_type_id, p_title, p_message,
    p_related_table, p_related_record_id, 'pending'
  );

  update public.notification_dispatch_log
  set status = 'created',
      notification_id = v_notification_id,
      processed_at = timezone('utc', now())
  where idempotency_key = v_key;

  return v_notification_id;
end;
$$;

-- Only the service role (webhook) and internal callers should reach this; never
-- expose it to app clients (they must not fabricate notifications for others).
revoke all on function public.enqueue_notification_system(
  uuid, text, text, text, jsonb, text, text, uuid, text
) from public, anon, authenticated;
grant execute on function public.enqueue_notification_system(
  uuid, text, text, text, jsonb, text, text, uuid, text
) to service_role;

-- ---------------------------------------------------------------------------
-- Item 12: coin-purchase confirmation wording at the coin_transactions chokepoint.
-- Same trigger as notify_coins_earned but coin_purchase credits get a dedicated
-- "Purchase complete!" title/message; challenge_prize stays suppressed (item 3).
-- ---------------------------------------------------------------------------
create or replace function public.notify_coins_earned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_id uuid;
  v_tt_code text;
  v_reason text;
  v_title text;
  v_message text;
begin
  if new.amount is null or new.amount <= 0 then
    return new;
  end if;

  select code into v_tt_code
  from public.transaction_types
  where id = new.transaction_type_id;

  -- Challenge prizes get the richer challenge_result notification instead.
  if v_tt_code = 'challenge_prize' then
    return new;
  end if;

  v_type_id := public.ensure_notification_type('coins_earned', 'Coins earned');

  if v_tt_code = 'coin_purchase' then
    v_title := 'Purchase complete!';
    v_message := 'Your ' || new.amount || ' FL Coins are ready to spend.';
  else
    v_title := 'Coins earned!';
    v_reason := nullif(btrim(coalesce(new.description, '')), '');
    v_message := case
      when v_reason is null then 'You earned ' || new.amount || ' coins.'
      else 'You earned ' || new.amount || ' coins for ' || v_reason || '.'
    end;
  end if;

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
        'reason', coalesce(nullif(btrim(coalesce(new.description, '')), ''), '')
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

-- ---------------------------------------------------------------------------
-- Item 8: "your free trial is ending soon" — time-based, so driven by cron.
-- Paddle sends no pre-expiry event; scan trials whose trial_ends_at falls inside
-- the next 3 days and notify once (idempotency key is per subscription).
-- ---------------------------------------------------------------------------
create or replace function public.notify_trials_ending_soon()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub record;
  v_count integer := 0;
  v_days integer;
  v_msg text;
begin
  for v_sub in
    select id, user_id, trial_ends_at
    from public.subscriptions
    where status = 'trial'
      and trial_ends_at is not null
      and trial_ends_at > now()
      and trial_ends_at <= now() + interval '3 days'
  loop
    v_days := greatest(1, ceil(extract(epoch from (v_sub.trial_ends_at - now())) / 86400.0)::int);
    v_msg := case
      when v_days = 1 then 'Your free trial ends tomorrow. Keep Premium to stay subscribed.'
      else format('Your free trial ends in %s days. Keep Premium to stay subscribed.', v_days)
    end;

    if public.enqueue_notification_system(
      v_sub.user_id,
      'trial_ending',
      'Trial ending soon',
      v_msg,
      jsonb_build_object('type', 'trial_ending'),
      '/subscription',
      'subscriptions',
      v_sub.id,
      'trial_ending:' || v_sub.id::text
    ) is not null then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

-- Run daily. The idempotency key means re-runs within the window are no-ops.
do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'flap_notify_trials_ending';
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_notify_trials_ending',
  '0 9 * * *',
  $$select public.notify_trials_ending_soon();$$
);
