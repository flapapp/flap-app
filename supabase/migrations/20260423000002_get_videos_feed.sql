-- Enriched read model + RPC: filter/sort in PostgreSQL (PostgREST / Flutter client).
-- [20260423_000004_videos_independent_of_challenges.sql] replaces the view and RPC to drop
-- challenge–video coupling; re-apply that migration on top if you edit this file in isolation.

create or replace function public.profile_city_norm(p_city text)
returns text
language plpgsql
immutable
set search_path = public
as $fn$
declare
  c text;
begin
  if p_city is null or btrim(p_city) = '' then
    return '';
  end if;
  c := lower(btrim(split_part(p_city, ',', 1)));
  if c in ('kiev', 'kyiv', 'київ') or position('київ' in c) > 0 then
    return 'kyiv';
  end if;
  if c in ('lviv', 'львів', 'lwow') or position('львів' in c) > 0 then
    return 'lviv';
  end if;
  if c in ('odessa', 'odesa', 'одеса') or position('одеса' in c) > 0 then
    return 'odesa';
  end if;
  if c in ('kharkiv', 'харків', 'harkiv') or position('харків' in c) > 0 then
    return 'kharkiv';
  end if;
  if c in ('dnipro', 'дніпро', 'dnepropetrovsk', 'dnipropetrovsk', 'днепр') or
     position('дніпро' in c) > 0 or position('днепр' in c) > 0 then
    return 'dnipro';
  end if;
  if c in ('london', 'лондон') or position('london' in c) > 0 then
    return 'london';
  end if;
  return c;
end;
$fn$;

-- One row per video: aggregates + author + optional challenge (for non-feed rows, optional).
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
  (select count(*)::bigint from public.video_comments c
     where c.video_id = v.id and c.deleted_at is null) as comment_count
from public.videos v
join public.profiles p on p.id = v.user_id;

comment on view public.videos_feed_enriched is
  'Joins/aggregates for the video list; RLS on underlying public.videos.';

-- get_videos_feed(…): p_sort in
-- newest | rating_asc | rating_desc | views_desc | likes_desc | my_city
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
      order by f.like_count desc, f.created_at desc
      limit p_limit;
    return;
  end if;

  -- my_city: viewer’s normalized city first; tie-breaker newest
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
  'Filter/sort the video list in the database. Used by the Flutter app instead of client-only filtering.';

grant select on public.videos_feed_enriched to anon, authenticated, service_role;
grant execute on function public.get_videos_feed(
  uuid, text[], double precision, text, boolean, text, int
) to anon, authenticated, service_role;
grant execute on function public.profile_city_norm(text) to anon, authenticated, service_role;
