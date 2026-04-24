-- Sync DB lookup values with canonical dropdown enum values.
-- Canonical set (UI enums): goal, shot_power, pass, long_pass, dribbling,
-- tackle, defending, penalty, save, wall, strategy, trick, other.

-- Ensure canonical video category lookup rows exist (labels in English).
insert into public.video_categories (code, label)
values
  ('goal', 'Goal'),
  ('shot_power', 'Shot power'),
  ('pass', 'Pass'),
  ('long_pass', 'Long pass'),
  ('dribbling', 'Dribbling'),
  ('tackle', 'Tackle'),
  ('defending', 'Defending'),
  ('penalty', 'Penalty'),
  ('save', 'Save'),
  ('wall', 'Wall / set-piece'),
  ('strategy', 'Strategy'),
  ('trick', 'Freestyle'),
  ('other', 'Other')
on conflict (code) do update
set label = excluded.label;

-- Ensure canonical challenge type lookup rows exist.
insert into public.challenge_types (code, label)
values
  ('goal'::public.challenge_type_enum, 'Goal'),
  ('shot_power'::public.challenge_type_enum, 'Shot power'),
  ('pass'::public.challenge_type_enum, 'Pass'),
  ('long_pass'::public.challenge_type_enum, 'Long pass'),
  ('dribbling'::public.challenge_type_enum, 'Dribbling'),
  ('tackle'::public.challenge_type_enum, 'Tackle'),
  ('defending'::public.challenge_type_enum, 'Defending'),
  ('penalty'::public.challenge_type_enum, 'Penalty'),
  ('save'::public.challenge_type_enum, 'Save'),
  ('wall'::public.challenge_type_enum, 'Wall / set-piece'),
  ('strategy'::public.challenge_type_enum, 'Strategy'),
  ('trick'::public.challenge_type_enum, 'Freestyle'),
  ('other'::public.challenge_type_enum, 'Other')
on conflict (code) do update
set label = excluded.label;

-- Repoint challenges from legacy challenge type rows to canonical rows.
with legacy_map as (
  select
    old_ct.id as legacy_id,
    new_ct.id as canonical_id
  from public.challenge_types old_ct
  join public.challenge_types new_ct
    on new_ct.code = case old_ct.code::text
      when 'dribble' then 'dribbling'::public.challenge_type_enum
      when 'freestyle' then 'trick'::public.challenge_type_enum
      when 'technique' then 'dribbling'::public.challenge_type_enum
      when 'physics' then 'shot_power'::public.challenge_type_enum
      when 'teamplay' then 'pass'::public.challenge_type_enum
      else old_ct.code
    end
  where old_ct.code in (
    'dribble'::public.challenge_type_enum,
    'freestyle'::public.challenge_type_enum,
    'technique'::public.challenge_type_enum,
    'physics'::public.challenge_type_enum,
    'teamplay'::public.challenge_type_enum
  )
)
update public.challenges c
set challenge_type_id = lm.canonical_id
from legacy_map lm
where c.challenge_type_id = lm.legacy_id
  and lm.canonical_id is not null;

-- Remove legacy lookup rows now that data has been remapped.
delete from public.challenge_types
where code in (
  'dribble'::public.challenge_type_enum,
  'freestyle'::public.challenge_type_enum,
  'technique'::public.challenge_type_enum,
  'physics'::public.challenge_type_enum,
  'teamplay'::public.challenge_type_enum
);

delete from public.video_categories
where code in ('dribble', 'freestyle', 'technique', 'physics', 'teamplay');
