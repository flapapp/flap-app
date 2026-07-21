-- Friend-request declined notification (checklist item 22).
--
-- accept_friend_request_rpc already notifies the sender when their request is
-- ACCEPTED but says nothing on decline. This redefines it to also notify the
-- sender when the request is declined. Behaviour is otherwise identical to the
-- original; only the `else` (decline) branch is added. The decline notification
-- is packed (v:1) so the client gets an actionUrl to the friends page, and its
-- type_code `friend_declined` maps to the friend-request notification style.

create or replace function public.accept_friend_request_rpc(
  p_request_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.friend_requests%rowtype;
  v_type_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.friend_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Friend request not found';
  end if;
  if v_req.to_user_id <> v_uid then
    raise exception 'Not your friend request';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'Friend request already processed';
  end if;

  update public.friend_requests
  set status = case when p_accept then 'accepted' else 'declined' end,
      responded_at = now()
  where id = v_req.id;

  if p_accept then
    insert into public.friendships(user_id, friend_user_id, source_request_id)
    values
      (v_req.from_user_id, v_req.to_user_id, v_req.id),
      (v_req.to_user_id, v_req.from_user_id, v_req.id)
    on conflict (user_id, friend_user_id) do nothing;

    v_type_id := public.ensure_notification_type(
      'friend_request_accepted',
      'Friend request accepted'
    );

    insert into public.notifications(
      user_id, notification_type_id, title, message, related_table, related_record_id
    )
    values (
      v_req.from_user_id,
      v_type_id,
      'Friend request accepted',
      'Your friend request was accepted.',
      'friend_requests',
      v_req.id
    );
  else
    -- Item 22: tell the sender their request was declined.
    v_type_id := public.ensure_notification_type(
      'friend_declined',
      'Friend request declined'
    );

    insert into public.notifications(
      user_id, notification_type_id, title, message, related_table, related_record_id
    )
    values (
      v_req.from_user_id,
      v_type_id,
      'Friend request declined',
      jsonb_build_object(
        'v', 1,
        'displayMessage', 'Your friend request was declined.',
        'data', jsonb_build_object('type', 'friend_declined'),
        'actionUrl', '/friends',
        'imageUrl', null
      )::text,
      'friend_requests',
      v_req.id
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'status', case when p_accept then 'accepted' else 'declined' end
  );
end;
$$;
