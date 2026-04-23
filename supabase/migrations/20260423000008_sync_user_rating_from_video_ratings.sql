-- Keep creator rating snapshots in sync with video_ratings changes.
-- This guarantees that each video rating affects the creator's overall rating,
-- even when writes happen outside Flutter app logic.

create or replace function public.recompute_user_rating_snapshots(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_avg numeric;
  v_video_avg numeric;
  v_overall numeric;
begin
  if p_user_id is null then
    return;
  end if;

  select avg(mpr.overall_rating)::numeric
  into v_match_avg
  from public.match_player_ratings mpr
  where mpr.player_id = p_user_id;

  select avg(vr.overall_rating)::numeric
  into v_video_avg
  from public.video_ratings vr
  join public.videos v on v.id = vr.video_id
  where v.user_id = p_user_id;

  v_match_avg := coalesce(v_match_avg, 3.0);
  v_video_avg := coalesce(v_video_avg, 3.0);
  v_overall := (v_match_avg * 0.7) + (v_video_avg * 0.3);

  insert into public.user_rating_snapshots(user_id, rating_scope, rating_value)
  values
    (p_user_id, 'match', round(v_match_avg, 2)),
    (p_user_id, 'video', round(v_video_avg, 2)),
    (p_user_id, 'overall', round(v_overall, 2));
end;
$$;

create or replace function public.trg_recompute_creator_rating_from_video_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old_owner uuid;
  v_new_owner uuid;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select v.user_id into v_old_owner
    from public.videos v
    where v.id = old.video_id;
  end if;

  if tg_op in ('INSERT', 'UPDATE') then
    select v.user_id into v_new_owner
    from public.videos v
    where v.id = new.video_id;
  end if;

  if v_old_owner is not null then
    perform public.recompute_user_rating_snapshots(v_old_owner);
  end if;
  if v_new_owner is not null and v_new_owner is distinct from v_old_owner then
    perform public.recompute_user_rating_snapshots(v_new_owner);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_video_ratings_recompute_creator on public.video_ratings;
create trigger trg_video_ratings_recompute_creator
after insert or update or delete on public.video_ratings
for each row
execute function public.trg_recompute_creator_rating_from_video_rating();

-- Backfill current users once so existing data is aligned.
do $$
declare
  r record;
begin
  for r in select p.id from public.profiles p loop
    perform public.recompute_user_rating_snapshots(r.id);
  end loop;
end;
$$;
