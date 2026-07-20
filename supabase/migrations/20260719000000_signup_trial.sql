-- Move the 21-day free trial off the Paddle price and onto account creation.
--
-- New model: every newly created account gets a 21-day *premium* trial granted
-- server-side at signup (not via Paddle checkout). During the trial the user has
-- full premium access; when trial_ends_at passes, access is denied (client
-- checks the date immediately; a nightly cron flips the row to 'expired' for
-- server-side truth) and the user is prompted to subscribe to the paid plan.
--
-- Paddle prices must have their trial REMOVED in the dashboard so checkout
-- charges immediately.

-- 1. Grant a premium trial to newly created users. Fold it into the existing
--    auth-user bootstrap trigger (runs security-definer, bypassing RLS).
create or replace function public.bootstrap_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_signup_bonus_type_id uuid;
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, null)
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();

  insert into public.user_settings (
    user_id,
    locale,
    notifications_enabled,
    autoplay_videos
  )
  values (
    new.id,
    'en',
    true,
    true
  )
  on conflict (user_id) do nothing;

  select tt.id
  into v_signup_bonus_type_id
  from public.transaction_types tt
  where tt.code = 'signup_bonus'
  limit 1;

  if v_signup_bonus_type_id is not null then
    insert into public.coin_transactions (
      user_id,
      transaction_type_id,
      amount,
      description
    )
    select
      new.id,
      v_signup_bonus_type_id,
      160,
      'Welcome coins'
    where not exists (
      select 1
      from public.coin_transactions ct
      where ct.user_id = new.id
        and ct.transaction_type_id = v_signup_bonus_type_id
        and ct.amount = 160
        and ct.description = 'Welcome coins'
    );
  end if;

  -- 21-day premium trial. Guarded so it never conflicts with the
  -- single-active-subscription unique index or a pre-existing subscription.
  insert into public.subscriptions (
    user_id, plan_id, status, starts_at, trial_ends_at, ends_at, auto_renew
  )
  select
    new.id, pp.id, 'trial', now(), now() + interval '21 days',
    now() + interval '21 days', false
  from public.subscription_plans pp
  where pp.code = 'premium'
    and not exists (
      select 1 from public.subscriptions s
      where s.user_id = new.id and s.status in ('trial', 'active')
    );

  return new;
end;
$$;

-- 2. Backfill EXISTING users, dated from their original signup. Only users still
--    within their 21-day window get a trial row; accounts older than that are
--    left with no premium row (already view-only), and users who already have a
--    trial/active subscription are skipped.
insert into public.subscriptions (
  user_id, plan_id, status, starts_at, trial_ends_at, ends_at, auto_renew
)
select
  u.id, pp.id, 'trial', u.created_at, u.created_at + interval '21 days',
  u.created_at + interval '21 days', false
from auth.users u
cross join (select id from public.subscription_plans where code = 'premium') pp
where u.created_at + interval '21 days' > now()
  and not exists (
    select 1 from public.subscriptions s
    where s.user_id = u.id and s.status in ('trial', 'active')
  );

-- 3. Nightly cron: expire trials whose window has closed. Client access already
--    ends at trial_ends_at; this keeps the DB the server-side source of truth.
create or replace function public.expire_lapsed_trials_rpc()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.subscriptions
  set status = 'expired', updated_at = now()
  where status = 'trial'
    and trial_ends_at is not null
    and trial_ends_at < now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'flap_expire_lapsed_trials';
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_expire_lapsed_trials',
  '30 3 * * *',
  $$select public.expire_lapsed_trials_rpc();$$
);
