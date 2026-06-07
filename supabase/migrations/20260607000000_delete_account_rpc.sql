-- Self-service account deletion.
--
-- public.profiles.id references auth.users(id) ON DELETE CASCADE, and every
-- app table references public.profiles(id) ON DELETE CASCADE, so removing the
-- auth user transitively removes all of the user's owned data (settings,
-- videos, friendships, match participation, badges, push tokens, etc.).
--
-- The anon/authenticated client cannot touch the `auth` schema directly, so we
-- expose a SECURITY DEFINER RPC that deletes only the *calling* user. It keys
-- strictly off auth.uid() — a caller can never delete another account.

create or replace function public.delete_account()
returns void
language plpgsql
volatile
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  -- Cascades through public.profiles to all owned rows.
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;
