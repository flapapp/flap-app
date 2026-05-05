-- Record what triggered an overall/match/video rating snapshot (for in-app history).

alter table public.user_rating_snapshots
  add column if not exists trigger_source text;

-- Replace single-arg function with two-arg (second defaults for RPC clients).
drop trigger if exists trg_recompute_rating_on_match_player_ratings_change
  on public.match_player_ratings;
drop trigger if exists trg_recompute_rating_on_video_ratings_change
  on public.video_ratings;
drop trigger if exists trg_recompute_rating_on_challenge_submission_ratings_change
  on public.challenge_submission_ratings;

drop function if exists public.recompute_player_overall_rating(uuid);

create or replace function public.recompute_player_overall_rating(
  p_user_id uuid,
  p_trigger_source text default null
)
returns table (
  overall_rating numeric(4,2),
  match_rating numeric(4,2),
  video_rating numeric(4,2)
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match_avg numeric(10,4);
  v_video_avg numeric(10,4);
  v_challenge_video_avg numeric(10,4);
  v_match numeric(4,2);
  v_video numeric(4,2);
  v_overall numeric(4,2);
  v_src text;
begin
  select avg(mpr.overall_rating)::numeric(10,4)
  into v_match_avg
  from public.match_player_ratings mpr
  where mpr.player_id = p_user_id;

  select avg(vr.overall_rating)::numeric(10,4)
  into v_video_avg
  from public.video_ratings vr
  join public.videos v on v.id = vr.video_id
  where v.user_id = p_user_id;

  select avg(csr.overall_rating)::numeric(10,4)
  into v_challenge_video_avg
  from public.challenge_submission_ratings csr
  join public.challenge_submissions cs on cs.id = csr.challenge_submission_id
  where cs.user_id = p_user_id;

  v_match := round(coalesce(v_match_avg, 3.0)::numeric, 2);
  v_video := round(
    coalesce(
      (coalesce(v_video_avg, 0) + coalesce(v_challenge_video_avg, 0)) /
        nullif((case when v_video_avg is null then 0 else 1 end) +
               (case when v_challenge_video_avg is null then 0 else 1 end), 0),
      3.0
    )::numeric,
    2
  );
  v_overall := round(((v_match * 0.7) + (v_video * 0.3))::numeric, 2);

  v_src := coalesce(nullif(trim(p_trigger_source), ''), 'recompute');

  insert into public.user_rating_snapshots (
    user_id,
    rating_scope,
    rating_value,
    trigger_source
  )
  values
    (p_user_id, 'overall', v_overall, v_src),
    (p_user_id, 'match', v_match, v_src),
    (p_user_id, 'video', v_video, v_src);

  update public.profiles
  set
    overall_rating = v_overall,
    updated_at = now()
  where id = p_user_id;

  return query
  select v_overall, v_match, v_video;
end;
$$;

create or replace function public.recompute_rating_from_match_rating_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recompute_player_overall_rating(
    coalesce(new.player_id, old.player_id),
    'match_rating'
  );
  return coalesce(new, old);
end;
$$;

create or replace function public.recompute_rating_from_video_rating_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_user uuid;
  v_old_user uuid;
begin
  if tg_op <> 'DELETE' then
    select user_id into v_new_user from public.videos where id = new.video_id;
  end if;

  if tg_op <> 'INSERT' then
    select user_id into v_old_user from public.videos where id = old.video_id;
  end if;

  if v_new_user is not null then
    perform public.recompute_player_overall_rating(v_new_user, 'video_rating');
  end if;

  if v_old_user is not null and v_old_user <> v_new_user then
    perform public.recompute_player_overall_rating(v_old_user, 'video_rating');
  end if;

  return coalesce(new, old);
end;
$$;

create or replace function public.recompute_rating_from_challenge_video_rating_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_user uuid;
  v_old_user uuid;
begin
  if tg_op <> 'DELETE' then
    select cs.user_id
    into v_new_user
    from public.challenge_submissions cs
    where cs.id = new.challenge_submission_id;
  end if;

  if tg_op <> 'INSERT' then
    select cs.user_id
    into v_old_user
    from public.challenge_submissions cs
    where cs.id = old.challenge_submission_id;
  end if;

  if v_new_user is not null then
    perform public.recompute_player_overall_rating(
      v_new_user,
      'challenge_submission_rating'
    );
  end if;

  if v_old_user is not null and v_old_user <> v_new_user then
    perform public.recompute_player_overall_rating(
      v_old_user,
      'challenge_submission_rating'
    );
  end if;

  return coalesce(new, old);
end;
$$;

create trigger trg_recompute_rating_on_match_player_ratings_change
after insert or update or delete on public.match_player_ratings
for each row
execute function public.recompute_rating_from_match_rating_change();

create trigger trg_recompute_rating_on_video_ratings_change
after insert or update or delete on public.video_ratings
for each row
execute function public.recompute_rating_from_video_rating_change();

create trigger trg_recompute_rating_on_challenge_submission_ratings_change
after insert or update or delete on public.challenge_submission_ratings
for each row
execute function public.recompute_rating_from_challenge_video_rating_change();

grant execute on function public.recompute_player_overall_rating(uuid, text) to authenticated, service_role;

-- Legacy path: keep inserts valid; tag rows from older video sync helper.
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

  insert into public.user_rating_snapshots(
    user_id,
    rating_scope,
    rating_value,
    trigger_source
  )
  values
    (p_user_id, 'match', round(v_match_avg, 2), 'legacy_video_sync'),
    (p_user_id, 'video', round(v_video_avg, 2), 'legacy_video_sync'),
    (p_user_id, 'overall', round(v_overall, 2), 'legacy_video_sync');
end;
$$;
