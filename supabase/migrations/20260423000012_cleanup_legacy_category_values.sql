-- Canonicalize legacy category values after enum alignment migration.
-- Normalizes persisted data while keeping backward-compatible enum labels.

-- 1) Videos: replace legacy enum values with canonical ones.
update public.videos
set category = 'dribbling'::public.video_category_enum
where category = 'dribble'::public.video_category_enum;

update public.videos
set category = 'trick'::public.video_category_enum
where category = 'freestyle'::public.video_category_enum;

-- 2) Challenge type lookup: normalize legacy codes.
--    challenge_types.code is challenge_type_enum after 20260423000011.
update public.challenge_types
set code = 'dribbling'::public.challenge_type_enum,
    label = case
      when label ilike '%drib%' then label
      when label ilike '%дрибл%' then label
      else 'Dribbling'
    end
where code = 'dribble'::public.challenge_type_enum;

update public.challenge_types
set code = 'trick'::public.challenge_type_enum,
    label = case
      when label ilike '%trick%' then label
      when label ilike '%трюк%' then label
      else 'Trick'
    end
where code = 'freestyle'::public.challenge_type_enum;
