-- Video interaction notifications: likes & comments (checklist items 28-29).
-- (Ratings already notify via rating_service -> video_vote / rating_changed.)
--
-- Triggers on video_likes / video_comments notify the video owner (and, for a
-- reply, the parent comment's author) through enqueue_notification_system, which
-- dedups on the idempotency key. For likes the key is per (video, liker), so an
-- unlike/relike never re-notifies; for comments it is per comment id.

-- Resolve a friendly display name for a profile, or 'Someone'.
create or replace function public._actor_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(btrim(display_name), ''),
    nullif(btrim(nickname), ''),
    nullif(btrim(concat_ws(' ', first_name, last_name)), ''),
    'Someone'
  )
  from public.profiles
  where id = p_user_id;
$$;

-- ---------------------------------------------------------------------------
-- Likes.
-- ---------------------------------------------------------------------------
create or replace function public.notify_video_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_title text;
  v_actor text;
begin
  select user_id, title into v_owner, v_title
  from public.videos
  where id = new.video_id;

  -- No owner, or self-like: nothing to notify.
  if v_owner is null or v_owner = new.user_id then
    return new;
  end if;

  v_actor := coalesce(public._actor_name(new.user_id), 'Someone');

  perform public.enqueue_notification_system(
    v_owner,
    'video_like',
    'New like',
    format('%s liked your video "%s".', v_actor, coalesce(nullif(btrim(v_title), ''), 'your video')),
    jsonb_build_object('type', 'video_like', 'videoId', new.video_id::text),
    '/video/' || new.video_id::text,
    'videos',
    new.video_id,
    'video_like:' || new.video_id::text || ':' || new.user_id::text
  );

  return new;
end;
$$;

drop trigger if exists video_likes_notify on public.video_likes;
create trigger video_likes_notify
after insert on public.video_likes
for each row
execute function public.notify_video_like();

-- ---------------------------------------------------------------------------
-- Comments (and replies).
-- ---------------------------------------------------------------------------
create or replace function public.notify_video_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_title text;
  v_actor text;
  v_parent_author uuid;
  v_action_url text := '/video/' || new.video_id::text;
begin
  if new.deleted_at is not null then
    return new;
  end if;

  select user_id, title into v_owner, v_title
  from public.videos
  where id = new.video_id;

  v_actor := coalesce(public._actor_name(new.user_id), 'Someone');

  -- Notify the video owner (unless they commented on their own video).
  if v_owner is not null and v_owner <> new.user_id then
    perform public.enqueue_notification_system(
      v_owner,
      'video_comment',
      'New comment',
      format('%s commented on your video "%s".', v_actor, coalesce(nullif(btrim(v_title), ''), 'your video')),
      jsonb_build_object('type', 'video_comment', 'videoId', new.video_id::text),
      v_action_url,
      'videos',
      new.video_id,
      'video_comment:' || new.id::text
    );
  end if;

  -- Notify the parent comment's author on a reply (unless that's the replier or
  -- the video owner, who was already told above).
  if new.parent_comment_id is not null then
    select user_id into v_parent_author
    from public.video_comments
    where id = new.parent_comment_id;

    if v_parent_author is not null
       and v_parent_author <> new.user_id
       and v_parent_author is distinct from v_owner then
      perform public.enqueue_notification_system(
        v_parent_author,
        'video_comment_reply',
        'New reply',
        format('%s replied to your comment.', v_actor),
        jsonb_build_object('type', 'video_comment_reply', 'videoId', new.video_id::text),
        v_action_url,
        'videos',
        new.video_id,
        'video_comment_reply:' || new.id::text
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists video_comments_notify on public.video_comments;
create trigger video_comments_notify
after insert on public.video_comments
for each row
execute function public.notify_video_comment();
