-- Decouple [public.videos] from challenges: submissions store [video_url] only;
-- [public.challenges] stores the creator/intro [video_url] and [video_thumbnail_url] separately.
-- Idempotent for environments that already have columns from a rebuilt [20260423_000001].

-- 1) challenges: own video URLs
alter table public.challenges
  add column if not exists video_url text;
alter table public.challenges
  add column if not exists video_thumbnail_url text;

-- Copy legacy ad-hoc column names if present
do $blk$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'challenges' and column_name = 'creator_video_url'
  ) then
    update public.challenges c
    set video_url = coalesce(btrim(c.video_url), c.creator_video_url)
    where c.video_url is null or btrim(c.video_url) = '';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'challenges' and column_name = 'creator_thumbnail_url'
  ) then
    update public.challenges c
    set video_thumbnail_url = coalesce(btrim(c.video_thumbnail_url), c.creator_thumbnail_url)
    where c.video_thumbnail_url is null or btrim(c.video_thumbnail_url) = '';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'challenges' and column_name = 'thumbnail_url'
  ) then
    update public.challenges c
    set video_thumbnail_url = coalesce(btrim(c.video_thumbnail_url), c.thumbnail_url)
    where c.video_thumbnail_url is null or btrim(c.video_thumbnail_url) = '';
  end if;
end;
$blk$;

-- 2) Backfill + drop [video_id] only when the legacy column still exists
do $blk$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'challenge_submissions'
      and column_name = 'video_id'
  ) then
    update public.challenge_submissions cs
    set video_url = coalesce(
      nullif(btrim(coalesce(cs.video_url, '')), ''),
      (select v.video_url from public.videos v where v.id = cs.video_id)
    )
    where cs.video_id is not null
      and (cs.video_url is null or btrim(cs.video_url) = '');

    if exists (
      select 1 from information_schema.table_constraints
      where constraint_schema = 'public'
        and table_name = 'challenge_submissions'
        and constraint_name = 'challenge_submissions_video_id_fkey'
    ) then
      alter table public.challenge_submissions
        drop constraint challenge_submissions_video_id_fkey;
    end if;

    alter table public.challenge_submissions
      drop column video_id;
  end if;
end;
$blk$;

-- 3) Feed view: [public.videos] only (no join to challenge_submissions)
create or replace view public.videos_feed_enriched
with (security_invoker = true) as
select
  v.id,
  v.user_id,
  v.title,
  v.description,
  v.category,
  v.video_url,
  v.thumbnail_url,
  v.created_at,
  v.updated_at,
  p.display_name as author_name,
  p.city as author_city,
  coalesce(
    (select avg(r.overall_rating)::double precision from public.video_ratings r where r.video_id = v.id),
    0
  ) as average_rating,
  (select count(*)::bigint from public.video_views vv where vv.video_id = v.id) as view_count,
  (select count(*)::bigint from public.video_likes vl where vl.video_id = v.id) as like_count,
  (select count(*)::bigint from public.video_comments c2
     where c2.video_id = v.id and c2.deleted_at is null) as comment_count
from public.videos v
join public.profiles p on p.id = v.user_id;

comment on view public.videos_feed_enriched is
  'Video feed: aggregates + author. Independent of challenges.';

-- 4) [get_videos_feed]: filter “non-feed” by title/description heuristics only
create or replace function public.get_videos_feed(
  p_only_user_id uuid default null,
  p_category_codes text[] default null,
  p_min_avg_rating double precision default null,
  p_city_key text default null,
  p_exclude_non_feed_videos boolean default true,
  p_sort text default 'newest',
  p_limit int default 200
) returns setof public.videos_feed_enriched
language plpgsql
volatile
security invoker
set search_path = public
as $body$
declare
  v_viewer text;
  v_sort text := p_sort;
begin
  v_viewer := (select public.profile_city_norm(pr.city) from public.profiles pr
               where pr.id = auth.uid() limit 1);

  if v_sort is null or btrim(v_sort) = '' then
    v_sort := 'newest';
  end if;
  if v_sort not in (
    'newest', 'rating_asc', 'rating_desc', 'views_desc', 'likes_desc', 'my_city'
  ) then
    v_sort := 'newest';
  end if;
  if p_limit is null or p_limit < 1 then
    p_limit := 200;
  end if;
  if p_limit > 500 then
    p_limit := 500;
  end if;

  if v_sort = 'newest' then
    return query
      select f.*
      from public.videos_feed_enriched f
      where
        (p_only_user_id is null or f.user_id = p_only_user_id)
        and (
          p_category_codes is null
          or array_length(p_category_codes, 1) is null
          or exists (
            select 1 from unnest(p_category_codes) as u(code)
            where f.category = code::public.video_category_enum
          )
        )
        and (
          p_min_avg_rating is null
          or p_min_avg_rating <= 0
          or f.average_rating >= p_min_avg_rating
        )
        and (
          p_city_key is null
          or btrim(p_city_key) = ''
          or public.profile_city_norm(f.author_city) = p_city_key
        )
        and (not p_exclude_non_feed_videos or (
          lower(btrim(coalesce(f.title, ''))) not in (
            'відео челенджу', 'challenge video', 'відео створювача'
          )
          and lower(btrim(coalesce(f.description, ''))) not in (
            'відео челенджу', 'challenge video'
          )
        ))
      order by f.created_at desc
      limit p_limit;
    return;
  end if;

  if v_sort = 'rating_asc' then
    return query
      select f.*
      from public.videos_feed_enriched f
      where
        (p_only_user_id is null or f.user_id = p_only_user_id)
        and (
          p_category_codes is null
          or array_length(p_category_codes, 1) is null
          or exists (
            select 1 from unnest(p_category_codes) as u(code)
            where f.category = code::public.video_category_enum
          )
        )
        and (
          p_min_avg_rating is null
          or p_min_avg_rating <= 0
          or f.average_rating >= p_min_avg_rating
        )
        and (
          p_city_key is null
          or btrim(p_city_key) = ''
          or public.profile_city_norm(f.author_city) = p_city_key
        )
        and (not p_exclude_non_feed_videos or (
          lower(btrim(coalesce(f.title, ''))) not in (
            'відео челенджу', 'challenge video', 'відео створювача'
          )
          and lower(btrim(coalesce(f.description, ''))) not in (
            'відео челенджу', 'challenge video'
          )
        ))
      order by f.average_rating asc nulls last, f.created_at desc
      limit p_limit;
    return;
  end if;

  if v_sort = 'rating_desc' then
    return query
      select f.*
      from public.videos_feed_enriched f
      where
        (p_only_user_id is null or f.user_id = p_only_user_id)
        and (
          p_category_codes is null
          or array_length(p_category_codes, 1) is null
          or exists (
            select 1 from unnest(p_category_codes) as u(code)
            where f.category = code::public.video_category_enum
          )
        )
        and (
          p_min_avg_rating is null
          or p_min_avg_rating <= 0
          or f.average_rating >= p_min_avg_rating
        )
        and (
          p_city_key is null
          or btrim(p_city_key) = ''
          or public.profile_city_norm(f.author_city) = p_city_key
        )
        and (not p_exclude_non_feed_videos or (
          lower(btrim(coalesce(f.title, ''))) not in (
            'відео челенджу', 'challenge video', 'відео створювача'
          )
          and lower(btrim(coalesce(f.description, ''))) not in (
            'відео челенджу', 'challenge video'
          )
        ))
      order by f.average_rating desc nulls last, f.created_at desc
      limit p_limit;
    return;
  end if;

  if v_sort = 'views_desc' then
    return query
      select f.*
      from public.videos_feed_enriched f
      where
        (p_only_user_id is null or f.user_id = p_only_user_id)
        and (
          p_category_codes is null
          or array_length(p_category_codes, 1) is null
          or exists (
            select 1 from unnest(p_category_codes) as u(code)
            where f.category = code::public.video_category_enum
          )
        )
        and (
          p_min_avg_rating is null
          or p_min_avg_rating <= 0
          or f.average_rating >= p_min_avg_rating
        )
        and (
          p_city_key is null
          or btrim(p_city_key) = ''
          or public.profile_city_norm(f.author_city) = p_city_key
        )
        and (not p_exclude_non_feed_videos or (
          lower(btrim(coalesce(f.title, ''))) not in (
            'відео челенджу', 'challenge video', 'відео створювача'
          )
          and lower(btrim(coalesce(f.description, ''))) not in (
            'відео челенджу', 'challenge video'
          )
        ))
      order by f.view_count desc, f.created_at desc
      limit p_limit;
    return;
  end if;

  if v_sort = 'likes_desc' then
    return query
      select f.*
      from public.videos_feed_enriched f
      where
        (p_only_user_id is null or f.user_id = p_only_user_id)
        and (
          p_category_codes is null
          or array_length(p_category_codes, 1) is null
          or exists (
            select 1 from unnest(p_category_codes) as u(code)
            where f.category = code::public.video_category_enum
          )
        )
        and (
          p_min_avg_rating is null
          or p_min_avg_rating <= 0
          or f.average_rating >= p_min_avg_rating
        )
        and (
          p_city_key is null
          or btrim(p_city_key) = ''
          or public.profile_city_norm(f.author_city) = p_city_key
        )
        and (not p_exclude_non_feed_videos or (
          lower(btrim(coalesce(f.title, ''))) not in (
            'відео челенджу', 'challenge video', 'відео створювача'
          )
          and lower(btrim(coalesce(f.description, ''))) not in (
            'відео челенджу', 'challenge video'
          )
        ))
      order by f.like_count desc, f.created_at desc
      limit p_limit;
    return;
  end if;

  if v_sort = 'my_city' then
    return query
      select f.*
      from public.videos_feed_enriched f
      where
        (p_only_user_id is null or f.user_id = p_only_user_id)
        and (
          p_category_codes is null
          or array_length(p_category_codes, 1) is null
          or exists (
            select 1 from unnest(p_category_codes) as u(code)
            where f.category = code::public.video_category_enum
          )
        )
        and (
          p_min_avg_rating is null
          or p_min_avg_rating <= 0
          or f.average_rating >= p_min_avg_rating
        )
        and (
          p_city_key is null
          or btrim(p_city_key) = ''
          or public.profile_city_norm(f.author_city) = p_city_key
        )
        and (not p_exclude_non_feed_videos or (
          lower(btrim(coalesce(f.title, ''))) not in (
            'відео челенджу', 'challenge video', 'відео створювача'
          )
          and lower(btrim(coalesce(f.description, ''))) not in (
            'відео челенджу', 'challenge video'
          )
        ))
      order by
        case
          when v_viewer is not null and btrim(v_viewer) <> ''
            and public.profile_city_norm(f.author_city) = v_viewer
          then 0
          else 1
        end,
        f.created_at desc
      limit p_limit;
    return;
  end if;
end;
$body$;

comment on function public.get_videos_feed is
  'Filter/sort the public.videos list. Excludes legacy challenge-mirror rows by title/description when requested.';

grant select on public.videos_feed_enriched to anon, authenticated, service_role;
grant execute on function public.get_videos_feed(
  uuid, text[], double precision, text, boolean, text, int
) to anon, authenticated, service_role;
