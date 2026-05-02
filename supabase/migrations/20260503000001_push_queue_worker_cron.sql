-- Periodically invoke Edge Function push-queue-worker so notifications enqueued by
-- DB triggers (see 20260428000200_notification_triggers_backend_only.sql) are delivered.
-- Client/API paths that use notification-command already trigger the worker inline.
--
-- One-time per Supabase project (SQL editor), after migration applies:
--   select vault.create_secret('https://YOUR_PROJECT_REF.supabase.co', 'flap_push_queue_worker_url');
--   select vault.create_secret('YOUR_SUPABASE_ANON_OR_SERVICE_ROLE_JWT', 'flap_push_queue_worker_jwt');

create extension if not exists pg_net with schema extensions;

create or replace function public._cron_invoke_push_queue_worker()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  base text;
  jwt text;
begin
  select ds.decrypted_secret into base
  from vault.decrypted_secrets ds
  where ds.name = 'flap_push_queue_worker_url'
  limit 1;

  select ds.decrypted_secret into jwt
  from vault.decrypted_secrets ds
  where ds.name = 'flap_push_queue_worker_jwt'
  limit 1;

  if base is null or jwt is null then
    raise warning
      'flap_invoke_push_queue_worker: missing vault secrets flap_push_queue_worker_url and/or flap_push_queue_worker_jwt';
    return;
  end if;

  perform net.http_post(
    url := rtrim(base, '/') || '/functions/v1/push-queue-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || jwt,
      'apikey', jwt
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 55000
  );
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'flap_invoke_push_queue_worker';
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_invoke_push_queue_worker',
  '* * * * *',
  $$select public._cron_invoke_push_queue_worker();$$
);

revoke all on function public._cron_invoke_push_queue_worker() from public;
