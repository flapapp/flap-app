-- Library videos (non-challenge feed), likes, votes, comments — Supabase replacement for Firestore `videos/*`.

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  author_name text not null default '',
  title text not null default '',
  description text not null default '',
  category text not null default '',
  difficulty text,
  video_url text not null,
  video_storage_path text,
  thumbnail_url text,
  thumbnail_storage_path text,
  thumbnail_generated boolean not null default false,
  thumbnail_type text,
  likes integer not null default 0,
  rating double precision not null default 0,
  vote_count integer not null default 0,
  views integer not null default 0,
  comments_count integer not null default 0,
  city text,
  challenge_id uuid references public.challenges (id) on delete set null,
  challenge_title text,
  is_challenge_video boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists videos_user_id_created_at_idx
  on public.videos (user_id, created_at desc);

create index if not exists videos_created_at_idx
  on public.videos (created_at desc);

create table if not exists public.video_likes (
  video_id uuid not null references public.videos (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table if not exists public.video_votes (
  video_id uuid not null references public.videos (id) on delete cascade,
  rated_by uuid not null references public.profiles (id) on delete cascade,
  rating double precision not null default 0,
  criteria jsonb not null default '{}'::jsonb,
  rated_at timestamptz not null default now(),
  primary key (video_id, rated_by)
);

create index if not exists video_votes_video_id_idx on public.video_votes (video_id);

create table if not exists public.video_comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  author_name text not null default '',
  body text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists video_comments_video_id_created_idx
  on public.video_comments (video_id, created_at desc);

-- Keep aggregate columns in sync (Firestore stored denormalized counts).
create or replace function public._library_videos_refresh_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  vid uuid := coalesce(new.video_id, old.video_id);
begin
  update public.videos v
  set
    likes = (select count(*)::int from public.video_likes where video_id = vid),
    updated_at = now()
  where v.id = vid;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_video_likes_refresh on public.video_likes;
create trigger trg_video_likes_refresh
  after insert or delete on public.video_likes
  for each row execute procedure public._library_videos_refresh_like_count();

create or replace function public._library_videos_refresh_vote_agg()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  vid uuid := coalesce(new.video_id, old.video_id);
  avg_rating double precision;
  cnt int;
begin
  select
    coalesce(round(avg(rating)::numeric, 2), 0)::double precision,
    count(*)::int
  into avg_rating, cnt
  from public.video_votes
  where video_id = vid;

  update public.videos v
  set
    rating = coalesce(avg_rating, 0),
    vote_count = coalesce(cnt, 0),
    updated_at = now()
  where v.id = vid;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_video_votes_refresh on public.video_votes;
create trigger trg_video_votes_refresh
  after insert or update or delete on public.video_votes
  for each row execute procedure public._library_videos_refresh_vote_agg();

create or replace function public._library_videos_refresh_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  vid uuid := coalesce(new.video_id, old.video_id);
begin
  update public.videos v
  set
    comments_count = (select count(*)::int from public.video_comments where video_id = vid),
    updated_at = now()
  where v.id = vid;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_video_comments_refresh_ins on public.video_comments;
create trigger trg_video_comments_refresh_ins
  after insert or delete on public.video_comments
  for each row execute procedure public._library_videos_refresh_comment_count();

create or replace function public.increment_video_views(p_video_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.videos
  set views = views + 1, updated_at = now()
  where id = p_video_id;
$$;

grant execute on function public.increment_video_views(uuid) to anon, authenticated;

alter table public.videos enable row level security;
alter table public.video_likes enable row level security;
alter table public.video_votes enable row level security;
alter table public.video_comments enable row level security;

drop policy if exists "videos_select_public" on public.videos;
create policy "videos_select_public"
  on public.videos for select
  to anon, authenticated
  using (true);

drop policy if exists "videos_insert_own" on public.videos;
create policy "videos_insert_own"
  on public.videos for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "videos_update_own" on public.videos;
create policy "videos_update_own"
  on public.videos for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "videos_delete_own" on public.videos;
create policy "videos_delete_own"
  on public.videos for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "video_likes_select_public" on public.video_likes;
create policy "video_likes_select_public"
  on public.video_likes for select
  to anon, authenticated
  using (true);

drop policy if exists "video_likes_insert_self" on public.video_likes;
create policy "video_likes_insert_self"
  on public.video_likes for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "video_likes_delete_self" on public.video_likes;
create policy "video_likes_delete_self"
  on public.video_likes for delete
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "video_votes_select_public" on public.video_votes;
create policy "video_votes_select_public"
  on public.video_votes for select
  to anon, authenticated
  using (true);

drop policy if exists "video_votes_insert_self" on public.video_votes;
create policy "video_votes_insert_self"
  on public.video_votes for insert
  to authenticated
  with check (rated_by = auth.uid());

drop policy if exists "video_votes_update_self" on public.video_votes;
create policy "video_votes_update_self"
  on public.video_votes for update
  to authenticated
  using (rated_by = auth.uid())
  with check (rated_by = auth.uid());

drop policy if exists "video_comments_select_public" on public.video_comments;
create policy "video_comments_select_public"
  on public.video_comments for select
  to anon, authenticated
  using (true);

drop policy if exists "video_comments_insert_self" on public.video_comments;
create policy "video_comments_insert_self"
  on public.video_comments for insert
  to authenticated
  with check (user_id = auth.uid());

-- Realtime (optional if not already in publication)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'videos'
  ) then
    alter publication supabase_realtime add table public.videos;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'video_likes'
  ) then
    alter publication supabase_realtime add table public.video_likes;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'video_votes'
  ) then
    alter publication supabase_realtime add table public.video_votes;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'video_comments'
  ) then
    alter publication supabase_realtime add table public.video_comments;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'wallet_transactions'
  ) then
    alter publication supabase_realtime add table public.wallet_transactions;
  end if;
end $$;

-- Storage buckets (public read for feed URLs)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('video-uploads', 'video-uploads', true, 26214400, array['video/mp4', 'video/quicktime']::text[]),
  ('video-thumbnails', 'video-thumbnails', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']::text[])
on conflict (id) do nothing;

drop policy if exists "Public read video-uploads" on storage.objects;
create policy "Public read video-uploads"
  on storage.objects for select
  using (bucket_id = 'video-uploads');

drop policy if exists "Users upload own video-uploads" on storage.objects;
create policy "Users upload own video-uploads"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'video-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users update own video-uploads" on storage.objects;
create policy "Users update own video-uploads"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'video-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users delete own video-uploads" on storage.objects;
create policy "Users delete own video-uploads"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'video-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Public read video-thumbnails" on storage.objects;
create policy "Public read video-thumbnails"
  on storage.objects for select
  using (bucket_id = 'video-thumbnails');

drop policy if exists "Users upload own video-thumbnails" on storage.objects;
create policy "Users upload own video-thumbnails"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'video-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users update own video-thumbnails" on storage.objects;
create policy "Users update own video-thumbnails"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'video-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Users delete own video-thumbnails" on storage.objects;
create policy "Users delete own video-thumbnails"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'video-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
