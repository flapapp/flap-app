-- Server-side bootstrap for newly created auth users.
-- Moves profile creation away from client-side inserts to avoid RLS failures
-- when sign-up returns no authenticated session (e.g. email confirmation flow).
-- Never infers display_name from email; onboarding must collect names explicitly.

alter table public.profiles
  alter column display_name drop not null;

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

  return new;
end;
$$;

drop trigger if exists trg_auth_user_bootstrap on auth.users;
create trigger trg_auth_user_bootstrap
  after insert on auth.users
  for each row
  execute function public.bootstrap_new_auth_user();
