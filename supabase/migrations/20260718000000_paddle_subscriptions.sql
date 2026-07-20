-- Paddle subscription system: collapse the legacy football tiers into a single
-- paid "premium" plan (billed monthly or yearly, with a free trial) and record
-- the Paddle-side identifiers so the webhook can keep the row in sync.
--
-- The client only ever READS subscription state; every write to a Paddle-backed
-- row happens in the `paddle-webhook` edge function using the service-role key,
-- which bypasses RLS. So no new client-facing policies are needed here.

-- 1. Premium plan row (legacy free/europa/champions rows are left in place so
--    existing subscription rows keep their FK, but the app no longer uses them).
--    price_monthly / price_yearly are stored in the smallest currency unit's
--    "dollars" for display only — the real amounts live in Paddle.
alter table public.subscription_plans
  add column if not exists price_yearly integer not null default 0
    check (price_yearly >= 0);

insert into public.subscription_plans (code, name, price_monthly, price_yearly, is_active)
values ('premium', 'Premium', 1, 10, true)
on conflict (code) do update
set
  name = excluded.name,
  price_monthly = excluded.price_monthly,
  price_yearly = excluded.price_yearly,
  is_active = excluded.is_active,
  updated_at = now();

-- 2. Paddle bookkeeping columns on the subscriptions table.
alter table public.subscriptions
  add column if not exists billing_interval text
    check (billing_interval is null or billing_interval in ('monthly', 'yearly')),
  add column if not exists paddle_subscription_id text,
  add column if not exists paddle_customer_id text,
  add column if not exists paddle_transaction_id text,
  add column if not exists current_period_end timestamptz;

-- 3. Extend the status check to include 'past_due' (payment-failure state).
--    The original inline column check is named subscriptions_status_check.
alter table public.subscriptions
  drop constraint if exists subscriptions_status_check;
alter table public.subscriptions
  add constraint subscriptions_status_check
  check (status in ('trial', 'active', 'past_due', 'expired', 'cancelled'));

-- 4. One DB row per Paddle subscription so webhook upserts are idempotent.
create unique index if not exists subscriptions_paddle_sub_uq
  on public.subscriptions (paddle_subscription_id)
  where paddle_subscription_id is not null;

-- Lookup by Paddle customer (renewals/updates arrive keyed by subscription id,
-- but customer lookups help reconciliation).
create index if not exists subscriptions_paddle_customer_idx
  on public.subscriptions (paddle_customer_id)
  where paddle_customer_id is not null;
