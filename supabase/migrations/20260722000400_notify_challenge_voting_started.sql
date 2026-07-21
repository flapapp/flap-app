-- Challenge "voting has started" notifications.
--
-- The `challenge_voting_started` event (typeCode challenge_update) is handled by
-- the edge function but never emitted. Challenges move submission -> voting
-- silently inside advance_challenge_statuses_rpc (the lifecycle sweep). This
-- redefines that RPC to capture the challenges transitioning INTO voting on this
-- run (selected before the status flip) and notify each of their participants to
-- go vote. Capturing pre-flip ids makes it naturally idempotent: once a challenge
-- is in 'voting' a later run no longer selects it, so participants are told once.
--
-- Only the notification fan-out is added; the status-transition logic is
-- unchanged from the original definition.

create or replace function public.advance_challenge_statuses_rpc()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_voting_ids uuid[];
  v_type_id uuid;
  v_cid uuid;
  v_title text;
  v_action_url text;
  v_msg text;
  v_participant record;
begin
  -- Challenges about to enter the voting phase, captured before the flip.
  select array_agg(id) into v_voting_ids
  from public.challenges
  where status = 'submission'
    and voting_deadline is not null
    and now() >= voting_deadline;

  update public.challenges
  set status = case
      when status = 'recruiting' and submission_deadline is not null and now() >= submission_deadline then 'submission'
      when status = 'submission' and voting_deadline is not null and now() >= voting_deadline then 'voting'
      when status = 'voting' and ends_at is not null and now() >= ends_at then 'completed'
      else status
    end,
    updated_at = now()
  where status in ('recruiting', 'submission', 'voting');

  get diagnostics v_count = row_count;

  if v_voting_ids is not null and array_length(v_voting_ids, 1) > 0 then
    v_type_id := public.ensure_notification_type('challenge_update', 'Challenge update');
    foreach v_cid in array v_voting_ids
    loop
      select title into v_title from public.challenges where id = v_cid;
      v_action_url := '/challenge-details/' || v_cid::text;
      v_msg := format('Voting has started in "%s". Cast your votes!', coalesce(v_title, 'a challenge'));

      for v_participant in
        select user_id
        from public.challenge_participants
        where challenge_id = v_cid
      loop
        insert into public.notifications(
          user_id, notification_type_id, title, message,
          related_table, related_record_id, is_read
        )
        values (
          v_participant.user_id,
          v_type_id,
          'Voting started',
          jsonb_build_object(
            'v', 1,
            'displayMessage', v_msg,
            'data', jsonb_build_object(
              'type', 'challenge_update',
              'challengeId', v_cid::text,
              'action', 'vote'
            ),
            'actionUrl', v_action_url,
            'imageUrl', null
          )::text,
          'challenges',
          v_cid,
          false
        );

        insert into public.push_notification_queue(
          user_id, notification_type_id, title, message,
          related_table, related_record_id, status
        )
        values (
          v_participant.user_id, v_type_id, 'Voting started', v_msg,
          'challenges', v_cid, 'pending'
        );
      end loop;
    end loop;
  end if;

  return v_count;
end;
$$;
