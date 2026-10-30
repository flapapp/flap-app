-- App Store (StoreKit) purchases alongside the existing Paddle ones.
--
-- iOS sells Premium and FL Coins through StoreKit because App Store guideline
-- 3.1.1 requires in-app purchase for digital content; Android and web keep
-- using Paddle. So every purchase record needs to say WHICH store it came from
-- and carry that store's transaction id.
--
-- As with Paddle, the client never writes these rows: it cannot be trusted to
-- state what it paid for. Coins are credited only by the `appstore-verify` /
-- `appstore-notifications` edge functions using the service-role key, against a
-- transaction payload cryptographically signed by Apple.

-- 1. coin_purchases: one row per store transaction, whichever store that is.
alter table public.coin_purchases
  add column if not exists app_store_transaction_id text;

-- paddle_transaction_id was NOT NULL because Paddle was the only store. It now
-- has to be null for App Store rows. The inline UNIQUE stays: Postgres allows
-- many NULLs in a unique column, so it keeps doing its job for Paddle rows.
alter table public.coin_purchases
  alter column paddle_transaction_id drop not null;

create unique index if not exists coin_purchases_app_store_txn_uq
  on public.coin_purchases (app_store_transaction_id)
  where app_store_transaction_id is not null;

-- Exactly one store reference per row — never both, never neither. Without this
-- a bug could write a row that no store's idempotency check would ever match,
-- letting the same purchase credit twice.
alter table public.coin_purchases
  drop constraint if exists coin_purchases_one_store_ref;
alter table public.coin_purchases
  add constraint coin_purchases_one_store_ref
  check (num_nonnulls(paddle_transaction_id, app_store_transaction_id) = 1);

-- 2. subscriptions: App Store identifiers.
--    originalTransactionId is the id that stays stable across every renewal of
--    an auto-renewable subscription, so it is the natural upsert key — the
--    direct counterpart of paddle_subscription_id.
alter table public.subscriptions
  add column if not exists app_store_original_transaction_id text,
  add column if not exists app_store_transaction_id text,
  add column if not exists app_store_product_id text;

create unique index if not exists subscriptions_app_store_original_txn_uq
  on public.subscriptions (app_store_original_transaction_id)
  where app_store_original_transaction_id is not null;

-- 3. Shared crediting logic.
--
--    credit_coin_purchase() already had the idempotency dance exactly right
--    (claim the transaction id FIRST, then write the ledger entry, so a loser of
--    the race can never leave an orphaned credit). Rather than copy it for
--    Apple and let the two drift, both stores now delegate to one internal
--    function; credit_coin_purchase keeps its original signature so the
--    already-deployed paddle-webhook keeps working untouched.
create or replace function public.credit_store_coin_purchase(
  p_user_id uuid,
  p_store text,
  p_store_transaction_id text,
  p_coins integer,
  p_amount_cents integer default 0,
  p_currency text default 'USD',
  p_paddle_customer_id text default null
) returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_purchase_id uuid;
  v_txn_type_id uuid;
  v_coin_txn_id uuid;
  v_existing_coins integer;
begin
  if p_user_id is null then
    raise exception 'credit_store_coin_purchase: user_id is required';
  end if;
  if p_store is null or p_store not in ('paddle', 'app_store') then
    raise exception 'credit_store_coin_purchase: unknown store %', p_store;
  end if;
  if p_store_transaction_id is null or p_store_transaction_id = '' then
    raise exception 'credit_store_coin_purchase: store_transaction_id is required';
  end if;
  if p_coins is null or p_coins <= 0 then
    raise exception 'credit_store_coin_purchase: coins must be positive, got %', p_coins;
  end if;

  select id into v_txn_type_id
  from public.transaction_types
  where code = 'coin_purchase';

  if v_txn_type_id is null then
    raise exception 'credit_store_coin_purchase: transaction type "coin_purchase" is not seeded';
  end if;

  -- Claim the store transaction. Losing this race (or replaying a delivery)
  -- means the coins are already credited.
  begin
    insert into public.coin_purchases (
      user_id, coins, amount_cents, currency,
      paddle_transaction_id, app_store_transaction_id, paddle_customer_id
    )
    values (
      p_user_id, p_coins, coalesce(p_amount_cents, 0), coalesce(p_currency, 'USD'),
      case when p_store = 'paddle' then p_store_transaction_id end,
      case when p_store = 'app_store' then p_store_transaction_id end,
      case when p_store = 'paddle' then p_paddle_customer_id end
    )
    returning id into v_purchase_id;
  exception
    when unique_violation then
      select coins into v_existing_coins
      from public.coin_purchases
      where (p_store = 'paddle' and paddle_transaction_id = p_store_transaction_id)
         or (p_store = 'app_store' and app_store_transaction_id = p_store_transaction_id);
      return coalesce(v_existing_coins, 0);
  end;

  insert into public.coin_transactions (
    user_id, transaction_type_id, amount, description
  )
  values (
    p_user_id,
    v_txn_type_id,
    p_coins,
    format('Purchased %s FL Coins', p_coins)
  )
  returning id into v_coin_txn_id;

  update public.coin_purchases
  set coin_transaction_id = v_coin_txn_id
  where id = v_purchase_id;

  return p_coins;
end;
$$;

-- Unchanged signature, unchanged behaviour — now a thin delegation so there is
-- only one copy of the logic above.
create or replace function public.credit_coin_purchase(
  p_user_id uuid,
  p_paddle_transaction_id text,
  p_coins integer,
  p_amount_cents integer default 0,
  p_currency text default 'USD',
  p_paddle_customer_id text default null
) returns integer
language sql
security definer
set search_path = public
as $$
  select public.credit_store_coin_purchase(
    p_user_id, 'paddle', p_paddle_transaction_id,
    p_coins, p_amount_cents, p_currency, p_paddle_customer_id
  );
$$;

create or replace function public.credit_appstore_coin_purchase(
  p_user_id uuid,
  p_app_store_transaction_id text,
  p_coins integer,
  p_amount_cents integer default 0,
  p_currency text default 'USD'
) returns integer
language sql
security definer
set search_path = public
as $$
  select public.credit_store_coin_purchase(
    p_user_id, 'app_store', p_app_store_transaction_id,
    p_coins, p_amount_cents, p_currency, null
  );
$$;

-- Service-role only, all three. Leaving any of them callable by `authenticated`
-- would let any signed-in user mint coins for free.
revoke all on function public.credit_store_coin_purchase(uuid, text, text, integer, integer, text, text)
  from public, anon, authenticated;
revoke all on function public.credit_coin_purchase(uuid, text, integer, integer, text, text)
  from public, anon, authenticated;
revoke all on function public.credit_appstore_coin_purchase(uuid, text, integer, integer, text)
  from public, anon, authenticated;
