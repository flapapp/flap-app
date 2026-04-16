-- View increments must bypass "only owner may update videos" RLS; clients call this RPC instead.

create or replace function public.increment_video_views(p_video_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.videos
  set view_count = view_count + 1
  where id = p_video_id
    and deleted_at is null;
end;
$$;

grant execute on function public.increment_video_views(uuid) to authenticated;
