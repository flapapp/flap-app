-- Enable supabase_flutter `.stream()` for invites and requests (same pattern as `teams`).
do $$
begin
  alter publication supabase_realtime add table public.team_invites;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.team_join_requests;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.team_match_requests;
exception
  when duplicate_object then null;
end $$;
