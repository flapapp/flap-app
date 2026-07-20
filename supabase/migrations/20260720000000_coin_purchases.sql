-- One-time FL Coin purchases via Paddle, at a fixed rate of 10 FL Coins = $1 USD.
--
-- Coins are credited ONLY by the `paddle-webhook` edge function using the
-- service-role key. The client never writes its own coin purchase: it cannot be
-- trusted to state how much it paid, and `coin_transactions` already allows a
-- client INSERT for its own user_id (policy coin_transactions_insert_own), so a
-- purchase must be provable against a signed Paddle payload instead.
--
-- `coin_purchases` doubles as the idempotency ledger — one row per Paddle
-- transaction id — because Paddle retries a failed notification for up to ~3
-- days and a manual replay re-sends the original event.

insert into public.transaction_types (code, label)
values ('coin_purchase', 'FL Coin purchase')
on conflict (code) do update
set label = excluded.label;

create table if not exists public.coin_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- The ledger entry this purchase credited. Nullable only for the brief window
  -- inside credit_coin_purchase() between claiming the transaction id and
  -- writing the ledger row.
  coin_transaction_id uuid references public.coin_transactions(id) on delete set null,
  coins integer not null check (coins > 0),
  amount_cents integer not null default 0 check (amount_cents >= 0),
  currency text not null default 'USD',
  paddle_transaction_id text not null unique,
  paddle_customer_id text,
  created_at timestamptz not null default now()
);

create index if not exists coin_purchases_user_idx
  on public.coin_purchases (user_id, created_at desc);

alter table public.coin_purchases enable row level security;

-- Buyers can read their own purchase history; there is no client-facing write
-- policy at all, so every INSERT/UPDATE must come from the service role.
drop policy if exists coin_purchases_select_own on public.coin_purchases;
create policy coin_purchases_select_own
  on public.coin_purchases for select
  to authenticated
  using (user_id = auth.uid());

-- Atomically record a purchase and its coin ledger entry, returning the number
-- of coins the user now holds for that transaction.
--
-- Idempotent: a duplicate delivery of the same Paddle transaction id returns
-- the coins already credited without writing a second ledger entry. The unique
-- index on paddle_transaction_id is what makes that safe under concurrent
-- deliveries — we claim the row FIRST, then write the ledger entry, so a loser
-- of the race can never leave an orphaned credit behind.
create or replace function public.credit_coin_purchase(
  p_user_id uuid,
  p_paddle_transaction_id text,
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
    raise exception 'credit_coin_purchase: user_id is required';
  end if;
  if p_paddle_transaction_id is null or p_paddle_transaction_id = '' then
    raise exception 'credit_coin_purchase: paddle_transaction_id is required';
  end if;
  if p_coins is null or p_coins <= 0 then
    raise exception 'credit_coin_purchase: coins must be positive, got %', p_coins;
  end if;

  select id into v_txn_type_id
  from public.transaction_types
  where code = 'coin_purchase';

  if v_txn_type_id is null then
    raise exception 'credit_coin_purchase: transaction type "coin_purchase" is not seeded';
  end if;

  -- Claim the Paddle transaction. Losing this race (or replaying a delivery)
  -- means the coins are already credited.
  begin
    insert into public.coin_purchases (
      user_id, coins, amount_cents, currency,
      paddle_transaction_id, paddle_customer_id
    )
    values (
      p_user_id, p_coins, coalesce(p_amount_cents, 0), coalesce(p_currency, 'USD'),
      p_paddle_transaction_id, p_paddle_customer_id
    )
    returning id into v_purchase_id;
  exception
    when unique_violation then
      select coins into v_existing_coins
      from public.coin_purchases
      where paddle_transaction_id = p_paddle_transaction_id;
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

-- Service-role only: the webhook is the sole caller. Leaving this callable by
-- `authenticated` would let any signed-in user mint coins for free.
revoke all on function public.credit_coin_purchase(uuid, text, integer, integer, text, text)
  from public, anon, authenticated;
