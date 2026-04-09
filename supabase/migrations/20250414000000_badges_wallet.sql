-- Badges catalog, ownership, wallet ledger, and atomic purchase/award RPCs.

alter table public.profiles
  add column if not exists friends_count integer not null default 0;

create table if not exists public.badges (
  id text primary key,
  name text not null,
  emoji text not null default '🏆',
  description text not null default '',
  price integer not null default 0,
  category text not null default 'general',
  is_available boolean not null default true,
  release_date timestamptz
);

create table if not exists public.user_badges (
  user_id uuid not null references public.profiles (id) on delete cascade,
  badge_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null,
  amount integer not null default 0,
  badge_id text,
  badge_name text,
  description text,
  created_at timestamptz not null default now()
);

create index if not exists wallet_transactions_user_id_idx
  on public.wallet_transactions (user_id, created_at desc);

alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
alter table public.wallet_transactions enable row level security;

create policy "badges_select_authenticated"
  on public.badges for select
  to authenticated
  using (true);

create policy "badges_upsert_authenticated"
  on public.badges for insert
  to authenticated
  with check (true);

create policy "badges_update_authenticated"
  on public.badges for update
  to authenticated
  using (true)
  with check (true);

create policy "user_badges_select_authenticated"
  on public.user_badges for select
  to authenticated
  using (true);

create policy "wallet_select_own"
  on public.wallet_transactions for select
  to authenticated
  using (user_id = auth.uid());

-- Atomic purchase: deduct coins, grant badge, log transaction.
create or replace function public.purchase_badge(p_badge_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_price int;
  v_available boolean;
  v_coins int;
  v_name text;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select b.price, b.is_available, b.name
    into v_price, v_available, v_name
  from public.badges b
  where b.id = p_badge_id;

  if not found then
    raise exception 'badge_not_found' using errcode = 'P0001';
  end if;

  if not coalesce(v_available, false) then
    raise exception 'badge_unavailable' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.user_badges ub
    where ub.user_id = v_uid and ub.badge_id = p_badge_id
  ) then
    raise exception 'already_owned' using errcode = 'P0001';
  end if;

  select p.coins into v_coins
  from public.profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;

  if v_coins < v_price then
    raise exception 'insufficient_coins' using errcode = 'P0001';
  end if;

  update public.profiles
  set coins = coins - v_price
  where id = v_uid;

  insert into public.user_badges (user_id, badge_id)
  values (v_uid, p_badge_id);

  insert into public.wallet_transactions (
    user_id, type, amount, badge_id, badge_name, description
  ) values (
    v_uid,
    'badge_purchase',
    -v_price,
    p_badge_id,
    v_name,
    'Badge purchase: ' || coalesce(v_name, p_badge_id)
  );
end;
$$;

grant execute on function public.purchase_badge(text) to authenticated;

-- Self-service award (activity badges). Caller must be the recipient.
create or replace function public.award_badge(
  p_user_id uuid,
  p_badge_id text,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  if auth.uid() <> p_user_id then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.user_badges ub
    where ub.user_id = p_user_id and ub.badge_id = p_badge_id
  ) then
    return false;
  end if;

  insert into public.user_badges (user_id, badge_id)
  values (p_user_id, p_badge_id);

  insert into public.wallet_transactions (
    user_id, type, amount, badge_id, description
  ) values (
    p_user_id,
    'badge_awarded',
    0,
    p_badge_id,
    coalesce(p_reason, 'Badge received')
  );

  return true;
end;
$$;

grant execute on function public.award_badge(uuid, text, text) to authenticated;
