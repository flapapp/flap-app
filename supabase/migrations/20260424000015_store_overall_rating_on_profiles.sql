-- Persist computed player overall rating directly on profiles.

alter table public.profiles
  add column if not exists overall_rating numeric(4,2) not null default 3.00;

-- Backfill from latest overall snapshots when available.
with latest_overall as (
  select distinct on (user_id)
    user_id,
    rating_value
  from public.user_rating_snapshots
  where rating_scope = 'overall'
  order by user_id, created_at desc
)
update public.profiles p
set overall_rating = l.rating_value
from latest_overall l
where p.id = l.user_id;

-- Keep profiles.overall_rating in sync whenever overall snapshot is inserted.
create or replace function public.sync_profile_overall_rating_from_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rating_scope = 'overall' then
    update public.profiles
    set
      overall_rating = new.rating_value,
      updated_at = now()
    where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_profile_overall_rating_from_snapshot
  on public.user_rating_snapshots;

create trigger trg_sync_profile_overall_rating_from_snapshot
after insert on public.user_rating_snapshots
for each row
execute function public.sync_profile_overall_rating_from_snapshot();
