-- Add "defending" category to videos and challenges.

do $$
begin
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
end $$;

insert into public.video_categories (code, label)
values ('defending', 'Defending')
on conflict (code) do update
set label = excluded.label;

insert into public.challenge_types (code, label)
values ('defending', 'Defending')
on conflict (code) do update
set label = excluded.label;
