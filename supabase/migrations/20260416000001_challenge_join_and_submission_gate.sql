-- Join challenge: deduct entry fee via wallet (idempotent). Gate submissions when entry_fee > 0.

create unique index if not exists idx_transactions_challenge_entry_unique
on public.transactions (user_id, reference_id)
where type = 'CHALLENGE_ENTRY' and reference_type = 'CHALLENGE';

create or replace function public.join_challenge(_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  _uid uuid := auth.uid();
  _c public.challenges;
  _fee numeric(14,2);
  _tx_id uuid;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into _c from public.challenges
  where id = _challenge_id and deleted_at is null;

  if not found then
    raise exception 'Challenge not found';
  end if;

  if _c.user_id = _uid then
    raise exception 'Challenge owner cannot join as participant';
  end if;

  if timezone('utc', now()) > _c.submit_due_date then
    raise exception 'Submission deadline has passed';
  end if;

  if exists (
    select 1 from public.challenge_submissions cs
    where cs.challenge_id = _challenge_id and cs.user_id = _uid
  ) then
    return;
  end if;

  if exists (
    select 1 from public.transactions t
    where t.user_id = _uid
      and t.type = 'CHALLENGE_ENTRY'
      and t.reference_type = 'CHALLENGE'
      and t.reference_id = _challenge_id
      and t.status = 'COMPLETED'
  ) then
    return;
  end if;

  _fee := coalesce(_c.entry_fee, 0);

  if _fee <= 0 then
    return;
  end if;

  begin
    insert into public.transactions (
      user_id,
      type,
      amount,
      currency,
      status,
      reference_id,
      reference_type,
      description
    ) values (
      _uid,
      'CHALLENGE_ENTRY',
      _fee,
      'COINS',
      'COMPLETED',
      _challenge_id,
      'CHALLENGE',
      'Challenge entry fee'
    )
    returning id into _tx_id;

    perform public.apply_completed_transaction(_tx_id);
  exception
    when unique_violation then
      -- Concurrent join: another session inserted the same entry payment.
      return;
  end;

  return;
end;
$$;

grant execute on function public.join_challenge(uuid) to authenticated;

create or replace function public.validate_challenge_submission()
returns trigger
language plpgsql
as $$
declare
  _challenge public.challenges;
  _submission_count integer;
begin
  select * into _challenge from public.challenges where id = new.challenge_id and deleted_at is null;
  if not found then
    raise exception 'Challenge not found';
  end if;

  if _challenge.user_id = new.user_id then
    raise exception 'Challenge owner cannot submit to own challenge';
  end if;

  if timezone('utc', now()) > _challenge.submit_due_date then
    raise exception 'Submission deadline has passed';
  end if;

  if coalesce(_challenge.entry_fee, 0) > 0 then
    if not exists (
      select 1 from public.transactions t
      where t.user_id = new.user_id
        and t.type = 'CHALLENGE_ENTRY'
        and t.reference_type = 'CHALLENGE'
        and t.reference_id = new.challenge_id
        and t.status = 'COMPLETED'
    ) then
      raise exception 'Challenge entry fee not paid';
    end if;
  end if;

  if _challenge.max_participants is not null then
    select count(*)::int into _submission_count
    from public.challenge_submissions cs
    where cs.challenge_id = new.challenge_id;

    if _submission_count >= _challenge.max_participants then
      raise exception 'Challenge has reached maximum participants';
    end if;
  end if;

  return new;
end;
$$;
