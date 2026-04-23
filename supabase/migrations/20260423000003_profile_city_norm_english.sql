-- Align [public.profile_city_norm] with app [CityCatalog.toEnglishStorageKey]: English slugs only.
-- Used by [get_videos_feed] for author city matching.

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
  if c in ('barcelona', 'барселона', 'барселон') or position('барселон' in c) > 0 then
    return 'barcelona';
  end if;
  if c in ('madrid', 'мадрид') or c like 'мадрид%' then
    return 'madrid';
  end if;
  if c in ('valencia', 'валенсія', 'valència') or position('валенс' in c) > 0 then
    return 'valencia';
  end if;
  if c in ('london', 'лондон') or position('лондон' in c) > 0 then
    return 'london';
  end if;
  if c in ('berlin', 'берлін') or position('берлін' in c) > 0 then
    return 'berlin';
  end if;
  if c in ('warsaw', 'warszawa', 'варшава') or position('варшав' in c) > 0 then
    return 'warsaw';
  end if;
  if c in ('prague', 'praha', 'прага') or position('праг' in c) > 0 then
    return 'prague';
  end if;
  if c in ('paris', 'parís', 'париж') or position('париж' in c) > 0 then
    return 'paris';
  end if;
  if c in ('rome', 'roma', 'рим', 'рім') or c like 'рим%' then
    return 'rome';
  end if;
  if c in ('lisbon', 'lisboa', 'лісабон') or position('лісабон' in c) > 0 then
    return 'lisbon';
  end if;
  if c ~ '^[a-z0-9_ ]+$' and length(c) <= 64 then
    return regexp_replace(c, '\s+', '_', 'g');
  end if;
  return c;
end;
$fn$;

comment on function public.profile_city_norm(text) is
  'Returns lowercase English city slug; matches app CityCatalog.';
