-- Subscription state on `profiles` (replaces Firestore `subscriptions` collection).

alter table public.profiles
  add column if not exists subscription_status text,
  add column if not exists subscription_trial_end timestamptz,
  add column if not exists subscription_auto_renew boolean not null default false,
  add column if not exists subscription_started_at timestamptz,
  add column if not exists champions_trial_used boolean not null default false,
  add column if not exists subscription_price integer not null default 0;

-- `subscription` text: use 'free' | 'europa' | 'champions' (legacy rows may use *_league).
update public.profiles
set subscription = 'champions'
where subscription in ('champions_league');

update public.profiles
set subscription = 'europa'
where subscription in ('europa_league');

-- Atomic coin credit + wallet row for subscription bonuses (client cannot insert wallet rows under RLS).
create or replace function public.subscription_credit_coins(p_amount integer, p_description text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount <= 0 then
    return;
  end if;

  update public.profiles
  set coins = coalesce(coins, 0) + p_amount,
      updated_at = now()
  where id = v_uid;

  insert into public.wallet_transactions (user_id, type, amount, description)
  values (v_uid, 'subscription_bonus', p_amount, coalesce(p_description, ''));
end;
$$;

grant execute on function public.subscription_credit_coins(integer, text) to authenticated;
