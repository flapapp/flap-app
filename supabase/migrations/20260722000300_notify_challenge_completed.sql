-- Challenge-completed broadcast to non-winning participants.
--
-- `challenge_completed` (sendChallengeCompletedNotification) is defined but never
-- called. This notifies every participant that a challenge they entered has
-- settled — but EXCLUDES the top-three winners, who already receive the richer
-- `challenge_result` notification (item 3), so nobody gets two notifications for
-- the same challenge. Emitted in _finalize_challenge alongside the result notifs,
-- covering both the cron and creator-triggered completion paths.

create or replace function public._finalize_challenge(
  p_challenge_id uuid,
  p_completed_by uuid default null
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry_fee integer;
  v_status text;
  v_title text;
  v_prize_type_id uuid;
  v_result_type_id uuid;
  v_completed_type_id uuid;
  v_participant_count integer;
  v_total integer;
  v_first integer;
  v_second integer;
  v_third integer;
  v_amount integer;
  v_winner record;
  v_participant record;
  v_winner_ids uuid[] := '{}';
  v_place_txt text;
  v_action_url text;
  v_msg text;
  v_completed_msg text;
begin
  select entry_fee, status, title
    into v_entry_fee, v_status, v_title
  from public.challenges
  where id = p_challenge_id;

  if not found then
    return false;
  end if;
  if v_status in ('completed', 'cancelled') then
    return false;
  end if;

  -- Claim the challenge. The unique constraint on challenge_id means only one
  -- concurrent caller proceeds; everyone else hits unique_violation and bails.
  begin
    insert into public.challenge_completions (challenge_id, completed_by)
    values (p_challenge_id, p_completed_by);
  exception
    when unique_violation then
      return false;
  end;

  select id into v_prize_type_id
  from public.transaction_types
  where code = 'challenge_prize';
  if v_prize_type_id is null then
    raise exception '_finalize_challenge: transaction type "challenge_prize" is not seeded';
  end if;

  v_result_type_id := public.ensure_notification_type('challenge_result', 'Challenge result');
  v_completed_type_id := public.ensure_notification_type('challenge_completed', 'Challenge completed');
  v_action_url := '/challenge-details/' || p_challenge_id::text;

  select count(*) into v_participant_count
  from public.challenge_participants
  where challenge_id = p_challenge_id;

  v_total := coalesce(v_participant_count, 0) * coalesce(v_entry_fee, 0);
  v_first := round(v_total * 0.5)::int;
  v_second := round(v_total * 0.3)::int;
  v_third := v_total - v_first - v_second;
  if v_third < 0 then
    v_third := 0;
  end if;

  -- Top three submissions by average overall rating (earliest submission wins
  -- ties), each awarded its place's share of the pot.
  for v_winner in
    select s.user_id,
           row_number() over (
             order by coalesce(avg(r.overall_rating), 0) desc, min(s.submitted_at) asc
           ) as place
    from public.challenge_submissions s
    left join public.challenge_submission_ratings r
      on r.challenge_submission_id = s.id
    where s.challenge_id = p_challenge_id
    group by s.id, s.user_id
    order by coalesce(avg(r.overall_rating), 0) desc, min(s.submitted_at) asc
    limit 3
  loop
    v_amount := case v_winner.place
      when 1 then v_first
      when 2 then v_second
      else v_third
    end;

    insert into public.challenge_prize_places
      (challenge_id, place, prize_amount, winner_user_id)
    values (p_challenge_id, v_winner.place, v_amount, v_winner.user_id)
    on conflict (challenge_id, place) do update
      set prize_amount = excluded.prize_amount,
          winner_user_id = excluded.winner_user_id;

    if v_amount > 0 then
      insert into public.coin_transactions
        (user_id, transaction_type_id, amount, description)
      values (
        v_winner.user_id,
        v_prize_type_id,
        v_amount,
        format('Prize for place %s in "%s"', v_winner.place, v_title)
      );
    end if;

    -- Result notification (placement matters even for a zero pot).
    v_place_txt := case v_winner.place
      when 1 then '1st'
      when 2 then '2nd'
      else '3rd'
    end;
    v_msg := case
      when v_amount > 0 then
        format('You finished %s in "%s" and won %s coins!', v_place_txt, v_title, v_amount)
      else
        format('You finished %s in "%s"!', v_place_txt, v_title)
    end;

    insert into public.notifications(
      user_id, notification_type_id, title, message,
      related_table, related_record_id, is_read
    )
    values (
      v_winner.user_id,
      v_result_type_id,
      'Challenge result!',
      jsonb_build_object(
        'v', 1,
        'displayMessage', v_msg,
        'data', jsonb_build_object(
          'type', 'challenge_result',
          'challengeId', p_challenge_id::text,
          'position', v_winner.place,
          'coinsWon', v_amount
        ),
        'actionUrl', v_action_url,
        'imageUrl', null
      )::text,
      'challenges',
      p_challenge_id,
      false
    );

    insert into public.push_notification_queue(
      user_id, notification_type_id, title, message,
      related_table, related_record_id, status
    )
    values (
      v_winner.user_id, v_result_type_id, 'Challenge result!', v_msg,
      'challenges', p_challenge_id, 'pending'
    );

    v_winner_ids := array_append(v_winner_ids, v_winner.user_id);
  end loop;

  -- Broadcast completion to everyone else who entered (winners already got the
  -- richer result notification above). `<> all('{}')` is true for all rows when
  -- there are no winners, so a prize-less challenge still notifies every entrant.
  v_completed_msg := format('"%s" has finished. Check out the results!', v_title);
  for v_participant in
    select user_id
    from public.challenge_participants
    where challenge_id = p_challenge_id
      and user_id <> all(v_winner_ids)
  loop
    insert into public.notifications(
      user_id, notification_type_id, title, message,
      related_table, related_record_id, is_read
    )
    values (
      v_participant.user_id,
      v_completed_type_id,
      'Challenge completed',
      jsonb_build_object(
        'v', 1,
        'displayMessage', v_completed_msg,
        'data', jsonb_build_object(
          'type', 'challenge_completed',
          'challengeId', p_challenge_id::text
        ),
        'actionUrl', v_action_url,
        'imageUrl', null
      )::text,
      'challenges',
      p_challenge_id,
      false
    );

    insert into public.push_notification_queue(
      user_id, notification_type_id, title, message,
      related_table, related_record_id, status
    )
    values (
      v_participant.user_id, v_completed_type_id, 'Challenge completed', v_completed_msg,
      'challenges', p_challenge_id, 'pending'
    );
  end loop;

  update public.challenges
  set status = 'completed'
  where id = p_challenge_id;

  return true;
end;
$$;

-- _finalize_challenge remains internal (it mints coins); re-assert the revoke in
-- case this replacement reset default grants.
revoke all on function public._finalize_challenge(uuid, uuid)
  from public, anon, authenticated;
