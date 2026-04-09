-- Allow thumbnail-only updates: empty p_creator_video_url keeps existing creator_video_url.

create or replace function public.challenge_set_creator_video(
  p_challenge_id uuid,
  p_creator_video_url text,
  p_creator_thumbnail_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  update public.challenges
  set
    creator_video_url = case
      when nullif(trim(coalesce(p_creator_video_url, '')), '') is not null
      then p_creator_video_url
      else creator_video_url
    end,
    creator_thumbnail_url = case
      when p_creator_thumbnail_url is not null
        and nullif(trim(p_creator_thumbnail_url), '') is not null
      then p_creator_thumbnail_url
      else creator_thumbnail_url
    end,
    updated_at = now()
  where id = p_challenge_id
    and creator_id = v_uid;

  if not found then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.challenge_set_creator_video(uuid, text, text) to authenticated;
