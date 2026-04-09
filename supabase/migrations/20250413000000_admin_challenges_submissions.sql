-- Admin tooling: challenge/submission storage on Supabase (mirrors Firestore collections conceptually).
-- Grant admin with: update public.profiles set is_admin = true where id = '<user-uuid>';

alter table public.profiles
  add column if not exists is_admin boolean not null default false;

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid references public.challenges (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.challenges enable row level security;
alter table public.submissions enable row level security;

-- No policies: direct client access denied; use RPC below (security definer).

create or replace function public.admin_delete_all_challenge_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_admin is true
  ) then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  truncate table public.submissions, public.challenges cascade;
end;
$$;

grant execute on function public.admin_delete_all_challenge_data() to authenticated;
