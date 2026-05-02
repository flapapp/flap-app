-- Badge like counts are derived from notifications rows targeted at the badge owner.
-- RLS on public.notifications only allows users to select their own rows, so the client
-- cannot aggregate another user's notifications. This SECURITY DEFINER RPC returns only
-- aggregate counts + whether the current viewer has endorsed (no raw notification body).

create or replace function public.badge_endorsement_stats(
  p_owner_user_id uuid,
  p_badge_id text
)
returns table (
  endorsement_count integer,
  endorsed_by_viewer boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tid uuid;
  v_viewer uuid := auth.uid();
begin
  if v_viewer is null then
    raise exception 'Authentication required';
  end if;

  select id into v_tid
  from public.notification_types
  where code = 'badge_endorsed'
  limit 1;

  if v_tid is null then
    return query select 0, false;
    return;
  end if;

  return query
  with parsed as (
    select
      coalesce(
        nullif(trim(n.message::jsonb #>> '{data,badgeId}'), ''),
        nullif(trim(n.message::jsonb->>'badgeId'), '')
      ) as bid,
      coalesce(
        nullif(trim(n.message::jsonb #>> '{data,endorserUserId}'), ''),
        nullif(trim(n.message::jsonb->>'endorserUserId'), '')
      ) as endorser_text
    from public.notifications n
    where n.user_id = p_owner_user_id
      and n.notification_type_id = v_tid
  ),
  filtered as (
    select endorser_text
    from parsed
    where bid = p_badge_id
      and endorser_text is not null
      and endorser_text <> ''
  )
  select
    (select count(distinct endorser_text)::integer from filtered),
    exists(
      select 1
      from filtered f
      where lower(f.endorser_text) = lower(v_viewer::text)
    );
end;
$$;

revoke all on function public.badge_endorsement_stats(uuid, text) from public;
grant execute on function public.badge_endorsement_stats(uuid, text) to authenticated;
