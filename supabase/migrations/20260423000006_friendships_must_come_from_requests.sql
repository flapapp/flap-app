-- Enforce that friendships can only be created from accepted friend requests.
-- Root cause fixed:
--   - previous RLS policy allowed any participant to insert directly into friendships.

-- Backfill source_request_id for legacy rows where we can infer accepted request.
with inferred as (
  select
    f.id as friendship_id,
    (
      select fr.id
      from public.friend_requests fr
      where fr.status = 'accepted'
        and (
          (fr.from_user_id = f.user_id and fr.to_user_id = f.friend_user_id)
          or
          (fr.from_user_id = f.friend_user_id and fr.to_user_id = f.user_id)
        )
      order by fr.responded_at desc nulls last, fr.created_at desc
      limit 1
    ) as request_id
  from public.friendships f
  where f.source_request_id is null
)
update public.friendships f
set source_request_id = i.request_id
from inferred i
where f.id = i.friendship_id
  and i.request_id is not null;

-- Remove orphan friendship rows that cannot be linked to an accepted request.
delete from public.friendships
where source_request_id is null;

-- Hard integrity check at DB level (applies to all roles, including service role).
create or replace function public.enforce_friendship_source_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.friend_requests%rowtype;
begin
  if new.source_request_id is null then
    raise exception 'friendships.source_request_id is required';
  end if;

  select *
  into v_req
  from public.friend_requests fr
  where fr.id = new.source_request_id;

  if not found then
    raise exception 'source friend request not found';
  end if;

  if v_req.status <> 'accepted' then
    raise exception 'friendship requires accepted friend request';
  end if;

  if not (
    (v_req.from_user_id = new.user_id and v_req.to_user_id = new.friend_user_id)
    or
    (v_req.from_user_id = new.friend_user_id and v_req.to_user_id = new.user_id)
  ) then
    raise exception 'friendship pair does not match source request';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_friendship_source_request on public.friendships;
create trigger trg_enforce_friendship_source_request
before insert or update on public.friendships
for each row
execute function public.enforce_friendship_source_request();

-- Tighten RLS: requester can only create own-direction row from accepted request.
drop policy if exists friendships_insert_participant on public.friendships;
create policy friendships_insert_from_accepted_request
  on public.friendships for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1
      from public.friend_requests fr
      where fr.id = source_request_id
        and fr.status = 'accepted'
        and (
          (fr.from_user_id = user_id and fr.to_user_id = friend_user_id)
          or
          (fr.from_user_id = friend_user_id and fr.to_user_id = user_id)
        )
    )
  );
