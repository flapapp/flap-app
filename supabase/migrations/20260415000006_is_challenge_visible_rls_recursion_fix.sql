-- is_challenge_visible_to_user reads public.challenges while the challenges SELECT
-- policy uses this function, causing RLS re-evaluation on the inner read and failing
-- INSERT ... RETURNING (and other paths). Run visibility checks as definer so the
-- inner SELECT is not blocked by the same policy chain.
begin;

create or replace function public.is_challenge_visible_to_user(_challenge_id uuid, _viewer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.challenges c
    left join public.user_profiles owner on owner.id = c.user_id
    left join public.user_profiles viewer on viewer.id = _viewer_id
    where c.id = _challenge_id
      and c.deleted_at is null
      and (
        c.user_id = _viewer_id
        or c.audience = 'WORLDWIDE'
        or (c.audience = 'FRIENDS' and public.are_friends(c.user_id, _viewer_id))
        or (c.audience = 'CITY' and owner.city is not null and viewer.city = owner.city)
        or (c.audience = 'COUNTRY' and owner.country is not null and viewer.country = owner.country)
      )
  );
$$;

commit;
