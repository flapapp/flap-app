-- Move overall rating computation to backend-side SQL logic.

create or replace function public.recompute_player_overall_rating(p_user_id uuid)
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

  insert into public.user_rating_snapshots (user_id, rating_scope, rating_value)
  values
    (p_user_id, 'overall', v_overall),
    (p_user_id, 'match', v_match),
    (p_user_id, 'video', v_video);

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
  perform public.recompute_player_overall_rating(coalesce(new.player_id, old.player_id));
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
    perform public.recompute_player_overall_rating(v_new_user);
  end if;

  if v_old_user is not null and v_old_user <> v_new_user then
    perform public.recompute_player_overall_rating(v_old_user);
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
    perform public.recompute_player_overall_rating(v_new_user);
  end if;

  if v_old_user is not null and v_old_user <> v_new_user then
    perform public.recompute_player_overall_rating(v_old_user);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_recompute_rating_on_match_player_ratings_change
  on public.match_player_ratings;
create trigger trg_recompute_rating_on_match_player_ratings_change
after insert or update or delete on public.match_player_ratings
for each row
execute function public.recompute_rating_from_match_rating_change();

drop trigger if exists trg_recompute_rating_on_video_ratings_change
  on public.video_ratings;
create trigger trg_recompute_rating_on_video_ratings_change
after insert or update or delete on public.video_ratings
for each row
execute function public.recompute_rating_from_video_rating_change();

drop trigger if exists trg_recompute_rating_on_challenge_submission_ratings_change
  on public.challenge_submission_ratings;
create trigger trg_recompute_rating_on_challenge_submission_ratings_change
after insert or update or delete on public.challenge_submission_ratings
for each row
execute function public.recompute_rating_from_challenge_video_rating_change();

grant execute on function public.recompute_player_overall_rating(uuid) to authenticated, service_role;
