-- Challenge-result notifications for prize winners.
--
-- The `challenge_result` notification type + `sendChallengeResultNotification`
-- helper exist but are never called, so _finalize_challenge pays the top three
-- winners without ever telling them they placed. This adds a per-winner result
-- notification (placement + title + coins, linking to the challenge) emitted in
-- the same server-side loop that credits each prize, so placement info is
-- captured exactly once, at the source, for both the cron and creator-triggered
-- paths.
--
-- To avoid a double notification, the generic coins-earned trigger is updated to
-- skip `challenge_prize` credits: the richer challenge-result notification is the
-- single notification a winner receives for a prize.

-- 1. Suppress the generic coins-earned notification for challenge prizes.
create or replace function public.notify_coins_earned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type_id uuid;
  v_tt_code text;
  v_reason text;
  v_title constant text := 'Coins earned!';
  v_message text;
begin
  if new.amount is null or new.amount <= 0 then
    return new;
  end if;

  -- Challenge prizes get the richer challenge_result notification instead.
  select code into v_tt_code
  from public.transaction_types
  where id = new.transaction_type_id;
  if v_tt_code = 'challenge_prize' then
    return new;
  end if;

  v_type_id := public.ensure_notification_type('coins_earned', 'Coins earned');

  v_reason := nullif(btrim(coalesce(new.description, '')), '');
  v_message := case
    when v_reason is null then 'You earned ' || new.amount || ' coins.'
    else 'You earned ' || new.amount || ' coins for ' || v_reason || '.'
  end;

  insert into public.notifications(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, is_read
  )
  values (
    new.user_id,
    v_type_id,
    v_title,
    jsonb_build_object(
      'v', 1,
      'displayMessage', v_message,
      'data', jsonb_build_object(
        'type', 'coins_earned',
        'amount', new.amount,
        'reason', coalesce(v_reason, '')
      ),
      'actionUrl', '/profile',
      'imageUrl', null
    )::text,
    'coin_transactions',
    new.id,
    false
  );

  insert into public.push_notification_queue(
    user_id, notification_type_id, title, message,
    related_table, related_record_id, status
  )
  values (
    new.user_id, v_type_id, v_title, v_message,
    'coin_transactions', new.id, 'pending'
  );

  return new;
end;
$$;

-- 2. Redefine _finalize_challenge to notify each winner of their result.
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
  v_participant_count integer;
  v_total integer;
  v_first integer;
  v_second integer;
  v_third integer;
  v_amount integer;
  v_winner record;
  v_place_txt text;
  v_action_url text;
  v_msg text;
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
