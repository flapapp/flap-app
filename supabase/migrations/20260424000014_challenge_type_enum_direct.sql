-- Store challenge type directly in challenges.type (enum), remove lookup FK table.

alter table public.challenges
  add column if not exists type public.challenge_type_enum;

update public.challenges c
set type = ct.code
from public.challenge_types ct
where c.challenge_type_id = ct.id
  and c.type is null;

update public.challenges
set type = 'other'::public.challenge_type_enum
where type is null;

alter table public.challenges
  alter column type set not null;

alter table public.challenges
  alter column type set default 'other'::public.challenge_type_enum;

alter table public.challenges
  drop column if exists challenge_type_id;

drop policy if exists challenge_types_select_all on public.challenge_types;
drop policy if exists challenge_types_write_admin on public.challenge_types;

drop table if exists public.challenge_types;
