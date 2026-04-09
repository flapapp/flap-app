-- Friend requests + RPCs (replaces Firestore friend_requests / users.friends arrays).
-- Uses existing public.user_friends (directed edges) and profiles.coins, friends_count, wallet_transactions.

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles (id) on delete cascade,
  to_user_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  message text,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  from_display_name text not null default '',
  from_avatar_url text not null default '',
  to_display_name text not null default '',
  to_avatar_url text not null default '',
  constraint friend_requests_no_self check (from_user_id <> to_user_id)
);

create unique index if not exists friend_requests_pending_pair_idx
  on public.friend_requests (from_user_id, to_user_id)
  where status = 'pending';

create index if not exists friend_requests_to_pending_idx
  on public.friend_requests (to_user_id, status, created_at desc);

create index if not exists friend_requests_from_pending_idx
  on public.friend_requests (from_user_id, status, created_at desc);

alter table public.friend_requests enable row level security;

drop policy if exists "friend_requests_select_parties" on public.friend_requests;
create policy "friend_requests_select_parties"
  on public.friend_requests for select
  to authenticated
  using (auth.uid() = from_user_id or auth.uid() = to_user_id);

-- No direct insert/update/delete; use RPCs below.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public._profile_display_name(p public.profiles)
returns text
language sql
immutable
as $$
  select coalesce(
    nullif(trim(p.display_name), ''),
    nullif(trim(concat_ws(' ', p.name, p.surname)), ''),
    nullif(split_part(coalesce(p.email, ''), '@', 1), ''),
    'User'
  );
$$;

create or replace function public.send_friend_request(
  p_to_user_id uuid,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_from uuid := auth.uid();
  v_id uuid;
  v_from_row public.profiles%rowtype;
  v_to_row public.profiles%rowtype;
begin
  if v_from is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  if p_to_user_id = v_from then
    raise exception 'cannot_friend_self' using errcode = 'P0001';
  end if;

  select * into v_from_row from public.profiles where id = v_from;
  if not found then
    raise exception 'sender_not_found' using errcode = 'P0001';
  end if;

  select * into v_to_row from public.profiles where id = p_to_user_id;
  if not found then
    raise exception 'target_not_found' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.user_friends
    where user_id = v_from and friend_id = p_to_user_id
  ) then
    raise exception 'already_friends' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.friend_requests
    where status = 'pending' and from_user_id = v_from and to_user_id = p_to_user_id
  ) then
    raise exception 'pending_request_exists' using errcode = 'P0001';
  end if;

  insert into public.friend_requests (
    from_user_id,
    to_user_id,
    status,
    message,
    from_display_name,
    from_avatar_url,
    to_display_name,
    to_avatar_url
  )
  values (
    v_from,
    p_to_user_id,
    'pending',
    p_message,
    public._profile_display_name(v_from_row),
    coalesce(v_from_row.avatar_url, ''),
    public._profile_display_name(v_to_row),
    coalesce(v_to_row.avatar_url, '')
  )
  returning id into v_id;

  update public.profiles
  set coins = coins + 3, updated_at = now()
  where id = v_from;

  insert into public.wallet_transactions (user_id, type, amount, description)
  values (
    v_from,
    'friend_request_sent',
    3,
    'Friend invite sent'
  );

  return v_id;
end;
$$;

grant execute on function public.send_friend_request(uuid, text) to authenticated;

create or replace function public.respond_friend_request(
  p_request_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.friend_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into r from public.friend_requests where id = p_request_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0001';
  end if;

  if r.to_user_id <> v_uid then
    raise exception 'not_recipient' using errcode = 'P0001';
  end if;

  if r.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  if p_accept then
    update public.friend_requests
    set
      status = 'accepted',
      responded_at = now()
    where id = p_request_id;

    insert into public.user_friends (user_id, friend_id)
    values (r.from_user_id, r.to_user_id)
    on conflict do nothing;
    insert into public.user_friends (user_id, friend_id)
    values (r.to_user_id, r.from_user_id)
    on conflict do nothing;

    update public.profiles
    set friends_count = friends_count + 1, updated_at = now()
    where id in (r.from_user_id, r.to_user_id);

    update public.profiles
    set coins = coins + 5, updated_at = now()
    where id = r.to_user_id;

    insert into public.wallet_transactions (user_id, type, amount, description)
    values (
      r.to_user_id,
      'friend_added',
      5,
      'New friend accepted'
    );
  else
    update public.friend_requests
    set
      status = 'declined',
      responded_at = now()
    where id = p_request_id;
  end if;
end;
$$;

grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;

create or replace function public.cancel_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.friend_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into r from public.friend_requests where id = p_request_id for update;
  if not found then
    raise exception 'request_not_found' using errcode = 'P0001';
  end if;

  if r.from_user_id <> v_uid then
    raise exception 'not_sender' using errcode = 'P0001';
  end if;

  if r.status <> 'pending' then
    raise exception 'not_pending' using errcode = 'P0001';
  end if;

  update public.friend_requests
  set
    status = 'cancelled',
    responded_at = now()
  where id = p_request_id;
end;
$$;

grant execute on function public.cancel_friend_request(uuid) to authenticated;

create or replace function public.remove_friendship(p_friend_id uuid)
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
  if p_friend_id = v_uid then
    raise exception 'cannot_friend_self' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.user_friends
    where user_id = v_uid and friend_id = p_friend_id
  ) then
    raise exception 'not_friends' using errcode = 'P0001';
  end if;

  delete from public.user_friends
  where (user_id = v_uid and friend_id = p_friend_id)
     or (user_id = p_friend_id and friend_id = v_uid);

  update public.profiles
  set
    friends_count = greatest(friends_count - 1, 0),
    updated_at = now()
  where id in (v_uid, p_friend_id);
end;
$$;

grant execute on function public.remove_friendship(uuid) to authenticated;
