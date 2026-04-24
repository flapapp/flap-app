-- Define aligned enums for video and challenge categories.
-- Keeps DB-level category values consistent across both domains.

do $$
begin
  -- video enum already exists in initial schema; add any missing aligned values.
  if exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'video_category_enum'
  ) then
    if not exists (
      select 1
      from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public'
        and t.typname = 'video_category_enum'
        and e.enumlabel = 'dribbling'
    ) then
      alter type public.video_category_enum add value 'dribbling';
    end if;

    if not exists (
      select 1
      from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public'
        and t.typname = 'video_category_enum'
        and e.enumlabel = 'trick'
    ) then
      alter type public.video_category_enum add value 'trick';
    end if;

    if not exists (
      select 1
      from pg_enum e
      join pg_type t on t.oid = e.enumtypid
      join pg_namespace n on n.oid = t.typnamespace
      where n.nspname = 'public'
        and t.typname = 'video_category_enum'
        and e.enumlabel = 'defending'
    ) then
      alter type public.video_category_enum add value 'defending';
    end if;
  end if;

  -- challenge enum: mirrors the same value set as video enum.
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'challenge_type_enum'
  ) then
    create type public.challenge_type_enum as enum (
      'goal',
      'shot_power',
      'pass',
      'long_pass',
      'dribble',
      'dribbling',
      'tackle',
      'defending',
      'penalty',
      'save',
      'wall',
      'strategy',
      'freestyle',
      'trick',
      'technique',
      'physics',
      'teamplay',
      'other'
    );
  end if;
end $$;

-- Enforce enum usage on challenge type lookup codes.
alter table public.challenge_types
  alter column code type public.challenge_type_enum
  using code::public.challenge_type_enum;

grant usage on type public.challenge_type_enum to anon, authenticated, service_role;
