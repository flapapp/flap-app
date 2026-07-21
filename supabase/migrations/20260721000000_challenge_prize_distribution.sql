-- Automatic challenge prize distribution.
--
-- Prizes must be credited to the WINNERS' coin ledgers, but the client can only
-- ever insert coin_transactions for its own user_id (policy
-- coin_transactions_insert_own), so it cannot pay other winners. Distribution
-- therefore runs entirely server-side in SECURITY DEFINER functions, and is
-- driven automatically by pg_cron once a challenge's `ends_at` has passed.
--
-- Idempotency: challenge_completions.challenge_id is UNIQUE, so the INSERT that
-- claims a challenge is the concurrency guard — a duplicate/replayed run loses
-- the race and no second set of credits is ever written.

-- Speeds up the cron sweep for challenges that have ended but aren't finalized.
create index if not exists challenges_due_finalize_idx
  on public.challenges (ends_at)
  where status not in ('completed', 'cancelled');

-- Finalizes a single challenge: claims it, scores submissions, and credits the
-- top three by average rating with a 50/30/20 split of the entry-fee pot
-- (participant_count * entry_fee), matching the app's prize math. Returns true
-- when THIS call performed the finalization, false when it was already done.
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
  v_participant_count integer;
  v_total integer;
  v_first integer;
  v_second integer;
  v_third integer;
  v_amount integer;
  v_winner record;
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
  end loop;

  update public.challenges
  set status = 'completed'
  where id = p_challenge_id;

  return true;
end;
$$;

-- Finalizes every challenge whose voting window has closed. Safe to run
-- repeatedly and concurrently (each challenge is claimed once); a failure on
-- one challenge is isolated so the rest of the batch still settles.
create or replace function public.finish_due_challenges()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_count integer := 0;
begin
  for v_id in
    select id
    from public.challenges
    where status not in ('completed', 'cancelled')
      and ends_at is not null
      and ends_at <= now()
    order by ends_at asc
    limit 50
  loop
    begin
      if public._finalize_challenge(v_id, null) then
        v_count := v_count + 1;
      end if;
    exception
      when others then
        raise warning 'finish_due_challenges: challenge % failed: %', v_id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$$;

-- Creator-triggered completion (the "Complete challenge" button). Same
-- distribution as the cron path, gated so only the creator (or an admin) can
-- settle their challenge early.
create or replace function public.complete_challenge(p_challenge_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_creator uuid;
  v_status text;
begin
  select creator_id, status into v_creator, v_status
  from public.challenges
  where id = p_challenge_id;

  if v_creator is null then
    raise exception 'complete_challenge: challenge not found';
  end if;
  if auth.uid() <> v_creator and not public.is_admin() then
    raise exception 'complete_challenge: only the creator can complete this challenge';
  end if;
  if v_status in ('completed', 'cancelled') then
    return false;
  end if;

  return public._finalize_challenge(p_challenge_id, auth.uid());
end;
$$;

-- _finalize_challenge is internal: it mints coins, so only the two wrapper
-- functions above (which run as owner) may reach it.
revoke all on function public._finalize_challenge(uuid, uuid)
  from public, anon, authenticated;

-- finish_due_challenges only ever acts on genuinely-ended challenges with
-- amounts derived from real data, so letting a signed-in client poke it (for an
-- immediate payout instead of waiting for the next cron tick) can't be gamed.
grant execute on function public.finish_due_challenges() to authenticated;
grant execute on function public.complete_challenge(uuid) to authenticated;

-- Run the sweep every minute so winners are paid shortly after voting closes,
-- independent of whether any client is online.
do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'flap_finish_due_challenges';
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_finish_due_challenges',
  '* * * * *',
  $$select public.finish_due_challenges();$$
);
