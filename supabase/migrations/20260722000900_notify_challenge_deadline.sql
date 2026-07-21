-- Challenge submission-deadline reminder (checklist item 25).
--
-- Reminds participants who have NOT yet submitted a video when a challenge's
-- submission_deadline is within the next 24h (while it is still in the
-- 'recruiting' phase, i.e. submissions are open). Cron-driven, once per
-- challenge/user via the idempotency key. Uses enqueue_notification_system.

create or replace function public.notify_challenge_deadlines_soon()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ch record;
  v_recipient record;
  v_count integer := 0;
  v_title text;
begin
  for v_ch in
    select id, title
    from public.challenges
    where status = 'recruiting'
      and submission_deadline is not null
      and submission_deadline > now()
      and submission_deadline <= now() + interval '24 hours'
  loop
    v_title := coalesce(nullif(btrim(v_ch.title), ''), 'a challenge');

    for v_recipient in
      select p.user_id
      from public.challenge_participants p
      where p.challenge_id = v_ch.id
        and not exists (
          select 1 from public.challenge_submissions s
          where s.challenge_id = v_ch.id and s.user_id = p.user_id
        )
    loop
      if public.enqueue_notification_system(
        v_recipient.user_id,
        'challenge_deadline',
        'Submission deadline soon',
        format('Time''s running out to submit your video for "%s".', v_title),
        jsonb_build_object('type', 'challenge_deadline', 'challengeId', v_ch.id::text),
        '/challenge-details/' || v_ch.id::text,
        'challenges',
        v_ch.id,
        'challenge_deadline:' || v_ch.id::text || ':' || v_recipient.user_id::text
      ) is not null then
        v_count := v_count + 1;
      end if;
    end loop;
  end loop;

  return v_count;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'flap_notify_challenge_deadlines';
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_notify_challenge_deadlines',
  '0 */2 * * *',
  $$select public.notify_challenge_deadlines_soon();$$
);
