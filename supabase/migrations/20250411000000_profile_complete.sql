-- Gate post-login profile completion (see registration flow).

alter table public.profiles
  add column if not exists profile_complete boolean not null default false;

-- Existing rows that already filled core fields are treated as complete.
update public.profiles
set profile_complete = true
where profile_complete = false
  and phone is not null
  and trim(phone) <> ''
  and city is not null
  and trim(city) <> ''
  and age is not null
  and position is not null
  and trim(position) <> ''
  and experience is not null
  and trim(experience) <> '';
