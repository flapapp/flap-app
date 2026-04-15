-- Soccer Networking App - Production-ready Supabase SQL (single migration: schema + legacy profile columns + avatar storage policies)
-- Source requirements: req.pdf
-- Target: Supabase Postgres
-- Notes:
--   1) This script creates the core schema, constraints, indexes, RLS, triggers, and RPC helpers.
--   2) Profile IDs are aligned 1:1 with auth.users(id), so business tables reference public.user_profiles(id).
--   3) Some complex orchestration is intentionally exposed as SECURITY DEFINER RPCs rather than overly complex triggers.

begin;

create extension if not exists pgcrypto;
create extension if not exists citext;

-- =========================================================
-- 1) ENUMS
-- =========================================================
create type public.player_position as enum ('GK', 'DEF', 'MID', 'FWD', 'OTHER');
create type public.player_experience as enum ('BEGINNER', 'AMATEUR', 'EXPERIENCED', 'PROFESSIONAL');

create type public.friend_request_status as enum ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED');

create type public.video_difficulty as enum ('EASY', 'MEDIUM', 'HARD', 'EXPERT');
create type public.content_visibility as enum ('PUBLIC', 'FRIENDS', 'PRIVATE');

create type public.challenge_type as enum (
  'GOAL', 'SHOT_POWER', 'PASS', 'LONG_PASS', 'DRIBBLING', 'TACKLE',
  'PENALTY', 'SAVE', 'WALL', 'STRATEGY', 'TRICK', 'FREESTYLE', 'OTHER'
);
create type public.challenge_audience as enum ('FRIENDS', 'CITY', 'COUNTRY', 'WORLDWIDE');
create type public.challenge_status as enum ('DRAFT', 'ACTIVE', 'VOTING', 'ENDED');
create type public.challenge_submission_status as enum ('PENDING', 'APPROVED', 'REJECTED');

create type public.team_role as enum ('OWNER', 'ADMIN', 'PLAYER');
create type public.team_membership_type as enum ('INVITE', 'REQUEST');
create type public.team_membership_status as enum ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED');

create type public.tournament_type as enum ('FRIENDLY', 'KNOCKOUT', 'LEAGUE');
create type public.tournament_status as enum ('DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED');
create type public.tournament_team_status as enum ('INVITED', 'APPROVED', 'REJECTED');
create type public.invitation_status as enum ('PENDING', 'ACCEPTED', 'REJECTED');
create type public.match_status as enum ('SCHEDULED', 'LIVE', 'COMPLETED', 'CANCELLED');
create type public.match_event_type as enum ('GOAL', 'ASSIST', 'FOUL', 'CARD', 'SAVE', 'SUBSTITUTION');

create type public.subscription_status as enum ('ACTIVE', 'EXPIRED', 'CANCELLED', 'PAST_DUE');
create type public.subscription_provider as enum ('STRIPE', 'TELEBIRR', 'MANUAL');

create type public.wallet_status as enum ('ACTIVE', 'SUSPENDED');
create type public.transaction_type as enum (
  'DEPOSIT', 'WITHDRAWAL', 'CHALLENGE_ENTRY', 'CHALLENGE_PRIZE', 'SUBSCRIPTION_PAYMENT', 'REFUND'
);
create type public.transaction_status as enum ('PENDING', 'COMPLETED', 'FAILED', 'CANCELLED');
create type public.transaction_reference_type as enum ('CHALLENGE', 'SUBSCRIPTION', 'WALLET');

create type public.notification_type as enum (
  'VIDEO_LIKE', 'VIDEO_COMMENT', 'VIDEO_RATING', 'FRIEND_REQUEST', 'FRIEND_ACCEPTED',
  'CHALLENGE_INVITE', 'CHALLENGE_SUBMISSION', 'CHALLENGE_RESULT', 'TEAM_INVITE',
  'TEAM_JOIN_REQUEST', 'TOURNAMENT_INVITE', 'MATCH_SCHEDULED', 'PAYMENT_SUCCESS', 'SYSTEM'
);
create type public.notification_reference_type as enum (
  'VIDEO', 'COMMENT', 'CHALLENGE', 'TEAM', 'TOURNAMENT', 'MATCH', 'TRANSACTION', 'USER'
);

create type public.device_platform as enum ('ANDROID', 'IOS', 'WEB');

-- =========================================================
-- 2) GENERIC HELPERS
-- =========================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.touch_updated_at(_table regclass, _id uuid)
returns void
language plpgsql
as $$
begin
  execute format('update %s set updated_at = timezone(''utc'', now()) where id = $1', _table)
  using _id;
end;
$$;

create or replace function public.is_same_user(_user_id uuid)
returns boolean
language sql
stable
as $$
  select auth.uid() = _user_id;
$$;

-- =========================================================
-- 3) USER PROFILES
-- =========================================================
create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  username citext not null unique,
  email citext unique,
  phone text,
  country text,
  city text,
  date_of_birth date,
  position public.player_position,
  experience public.player_experience,
  avatar_url text,
  bio text,
  profile_complete boolean not null default false,
  is_verified boolean not null default false,
  friends_count integer not null default 0,
  unread_notifications_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  -- Legacy Firestore-style fields (subscription, ratings, stats) used by the Flutter app
  rating numeric(5, 2) not null default 3.0,
  match_rating numeric(5, 2),
  video_rating numeric(5, 2),
  total_matches integer not null default 0,
  total_videos integer not null default 0,
  matches integer not null default 0,
  goals integer not null default 0,
  assists integer not null default 0,
  rating_history jsonb not null default '[]'::jsonb,
  coins integer not null default 0,
  wins integer not null default 0,
  losses integer not null default 0,
  draws integer not null default 0,
  settings jsonb not null default '{}'::jsonb,
  subscription text,
  subscription_expiry timestamptz,
  subscription_active boolean default true,
  subscription_status text,
  subscription_trial_end timestamptz,
  subscription_auto_renew boolean default false,
  subscription_started_at timestamptz,
  champions_trial_used boolean default false,
  subscription_price integer default 0,
  max_challenges_per_month integer default 1,
  display_name text,
  constraint username_not_blank check (btrim(username::text) <> ''),
  constraint email_format_basic check (email is null or position('@' in email::text) > 1)
);

create index idx_user_profiles_country_city on public.user_profiles(country, city);
create index idx_user_profiles_profile_complete on public.user_profiles(profile_complete);
create index idx_user_profiles_deleted_at on public.user_profiles(deleted_at);

create trigger trg_user_profiles_updated_at
before update on public.user_profiles
for each row execute function public.set_updated_at();

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (id, email, username, created_at, updated_at)
  values (
    new.id,
    new.email,
    lower(split_part(coalesce(new.email, 'user_' || new.id::text), '@', 1)) || '_' || substr(new.id::text, 1, 8),
    timezone('utc', now()),
    timezone('utc', now())
  )
  on conflict (id) do nothing;

  insert into public.notification_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into public.user_wallets (user_id, balance, locked_balance, currency, total_earned, total_spent)
  values (new.id, 0, 0, 'ETB', 0, 0)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- =========================================================
-- 4) FRIENDSHIP SYSTEM
-- =========================================================
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.user_profiles(id) on delete cascade,
  receiver_id uuid not null references public.user_profiles(id) on delete cascade,
  status public.friend_request_status not null default 'PENDING',
  message text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint friend_request_no_self check (sender_id <> receiver_id),
  constraint friend_request_unique_pair unique (sender_id, receiver_id)
);

create index idx_friend_requests_receiver_status on public.friend_requests(receiver_id, status);
create index idx_friend_requests_sender_status on public.friend_requests(sender_id, status);

create trigger trg_friend_requests_updated_at
before update on public.friend_requests
for each row execute function public.set_updated_at();

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  friend_id uuid not null references public.user_profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint friendship_no_self check (user_id <> friend_id),
  constraint friendship_unique_pair unique (user_id, friend_id)
);

create index idx_friendships_user_id on public.friendships(user_id);
create index idx_friendships_friend_id on public.friendships(friend_id);

create table public.blocked_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  blocked_user_id uuid not null references public.user_profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint blocked_users_no_self check (user_id <> blocked_user_id),
  constraint blocked_users_unique_pair unique (user_id, blocked_user_id)
);

create index idx_blocked_users_user_id on public.blocked_users(user_id);

create or replace function public.prevent_invalid_friend_request()
returns trigger
language plpgsql
as $$
begin
  if exists (
    select 1
    from public.blocked_users b
    where (b.user_id = new.sender_id and b.blocked_user_id = new.receiver_id)
       or (b.user_id = new.receiver_id and b.blocked_user_id = new.sender_id)
  ) then
    raise exception 'Friend request not allowed because one user has blocked the other';
  end if;

  if exists (
    select 1
    from public.friendships f
    where f.user_id = new.sender_id and f.friend_id = new.receiver_id
  ) then
    raise exception 'Users are already friends';
  end if;

  if exists (
    select 1
    from public.friend_requests fr
    where fr.sender_id = new.receiver_id
      and fr.receiver_id = new.sender_id
      and fr.status = 'PENDING'
  ) then
    raise exception 'Reverse pending friend request already exists';
  end if;

  return new;
end;
$$;

create trigger trg_friend_requests_prevent_invalid
before insert on public.friend_requests
for each row execute function public.prevent_invalid_friend_request();

create or replace function public.sync_friendship_from_request()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'ACCEPTED' and old.status is distinct from new.status then
    insert into public.friendships (user_id, friend_id)
    values (new.sender_id, new.receiver_id), (new.receiver_id, new.sender_id)
    on conflict do nothing;
  end if;

  if new.status in ('DECLINED', 'CANCELLED') and old.status = 'ACCEPTED' then
    delete from public.friendships
    where (user_id = new.sender_id and friend_id = new.receiver_id)
       or (user_id = new.receiver_id and friend_id = new.sender_id);
  end if;

  return new;
end;
$$;

create trigger trg_friend_requests_sync_friendship
after update on public.friend_requests
for each row execute function public.sync_friendship_from_request();

create or replace function public.refresh_friend_counts(_user_a uuid, _user_b uuid)
returns void
language plpgsql
as $$
begin
  update public.user_profiles
  set friends_count = (
    select count(*)::int from public.friendships f where f.user_id = _user_a
  )
  where id = _user_a;

  update public.user_profiles
  set friends_count = (
    select count(*)::int from public.friendships f where f.user_id = _user_b
  )
  where id = _user_b;
end;
$$;

create or replace function public.trg_refresh_friend_counts()
returns trigger
language plpgsql
as $$
declare
  _a uuid;
  _b uuid;
begin
  _a := coalesce(new.user_id, old.user_id);
  _b := coalesce(new.friend_id, old.friend_id);
  perform public.refresh_friend_counts(_a, _b);
  return coalesce(new, old);
end;
$$;

create trigger trg_friendships_refresh_counts_ins
after insert on public.friendships
for each row execute function public.trg_refresh_friend_counts();

create trigger trg_friendships_refresh_counts_del
after delete on public.friendships
for each row execute function public.trg_refresh_friend_counts();

-- =========================================================
-- 5) VIDEO / SOCIAL CONTENT
-- =========================================================
create table public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  title text not null,
  description text,
  category text,
  difficulty public.video_difficulty not null,
  visibility public.content_visibility not null default 'PUBLIC',
  video_url text not null,
  video_storage_path text not null,
  thumbnail_url text,
  thumbnail_storage_path text,
  thumbnail_generated boolean not null default false,
  duration_seconds integer,
  view_count bigint not null default 0,
  share_count bigint not null default 0,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  favorite_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint videos_title_not_blank check (btrim(title) <> ''),
  constraint videos_duration_non_negative check (duration_seconds is null or duration_seconds >= 0),
  constraint videos_view_count_non_negative check (view_count >= 0),
  constraint videos_share_count_non_negative check (share_count >= 0),
  constraint videos_like_count_non_negative check (like_count >= 0),
  constraint videos_comment_count_non_negative check (comment_count >= 0),
  constraint videos_favorite_count_non_negative check (favorite_count >= 0)
);

create index idx_videos_user_id_created_at on public.videos(user_id, created_at desc);
create index idx_videos_visibility_created_at on public.videos(visibility, created_at desc) where deleted_at is null;
create index idx_videos_category on public.videos(category) where deleted_at is null;
create index idx_videos_deleted_at on public.videos(deleted_at);

create trigger trg_videos_updated_at
before update on public.videos
for each row execute function public.set_updated_at();

create table public.video_likes (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint video_likes_unique unique (video_id, user_id)
);

create index idx_video_likes_video_id on public.video_likes(video_id);
create index idx_video_likes_user_id on public.video_likes(user_id);

create table public.video_comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  comment_text text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint video_comments_text_not_blank check (btrim(comment_text) <> '')
);

create index idx_video_comments_video_id_created_at on public.video_comments(video_id, created_at desc) where deleted_at is null;
create index idx_video_comments_user_id on public.video_comments(user_id);
create index idx_video_comments_deleted_at on public.video_comments(deleted_at);

create trigger trg_video_comments_updated_at
before update on public.video_comments
for each row execute function public.set_updated_at();

create table public.video_favorites (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  constraint video_favorites_unique unique (video_id, user_id)
);

create index idx_video_favorites_video_id on public.video_favorites(video_id);
create index idx_video_favorites_user_id on public.video_favorites(user_id);

create table public.video_ratings (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  overall_rating integer not null,
  technical_rating integer,
  creativity_rating integer,
  difficulty_rating integer,
  video_quality_rating integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint video_ratings_unique unique (video_id, user_id),
  constraint video_ratings_overall_range check (overall_rating between 1 and 5),
  constraint video_ratings_technical_range check (technical_rating is null or technical_rating between 1 and 5),
  constraint video_ratings_creativity_range check (creativity_rating is null or creativity_rating between 1 and 5),
  constraint video_ratings_difficulty_range check (difficulty_rating is null or difficulty_rating between 1 and 5),
  constraint video_ratings_quality_range check (video_quality_rating is null or video_quality_rating between 1 and 5)
);

create index idx_video_ratings_video_id on public.video_ratings(video_id);
create index idx_video_ratings_user_id on public.video_ratings(user_id);

create trigger trg_video_ratings_updated_at
before update on public.video_ratings
for each row execute function public.set_updated_at();

create or replace function public.update_video_counter()
returns trigger
language plpgsql
as $$
declare
  _video_id uuid;
  _table_name text := tg_table_name;
  _op text := tg_op;
begin
  _video_id := coalesce(new.video_id, old.video_id);

  if _table_name = 'video_likes' then
    update public.videos
    set like_count = (select count(*)::int from public.video_likes where video_id = _video_id)
    where id = _video_id;
  elsif _table_name = 'video_comments' then
    update public.videos
    set comment_count = (select count(*)::int from public.video_comments where video_id = _video_id and deleted_at is null)
    where id = _video_id;
  elsif _table_name = 'video_favorites' then
    update public.videos
    set favorite_count = (select count(*)::int from public.video_favorites where video_id = _video_id)
    where id = _video_id;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger trg_video_likes_counter_ins_del
after insert or delete on public.video_likes
for each row execute function public.update_video_counter();

create trigger trg_video_comments_counter_ins_upd_del
after insert or update or delete on public.video_comments
for each row execute function public.update_video_counter();

create trigger trg_video_favorites_counter_ins_del
after insert or delete on public.video_favorites
for each row execute function public.update_video_counter();

create or replace view public.video_rating_aggregates as
select
  vr.video_id,
  count(*)::int as rating_count,
  round(avg(vr.overall_rating)::numeric, 2) as avg_overall_rating,
  round(avg(vr.technical_rating)::numeric, 2) as avg_technical_rating,
  round(avg(vr.creativity_rating)::numeric, 2) as avg_creativity_rating,
  round(avg(vr.difficulty_rating)::numeric, 2) as avg_difficulty_rating,
  round(avg(vr.video_quality_rating)::numeric, 2) as avg_video_quality_rating
from public.video_ratings vr
group by vr.video_id;

-- =========================================================
-- 6) CHALLENGE SYSTEM
-- =========================================================
create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  title text not null,
  description text,
  type public.challenge_type not null,
  audience public.challenge_audience not null default 'WORLDWIDE',
  entry_fee numeric(14,2) not null default 0,
  max_participants integer,
  winner_count integer,
  submit_due_date timestamptz not null,
  vote_start_date timestamptz not null,
  vote_end_date timestamptz not null,
  prize_distribution jsonb,
  video_url text,
  video_storage_path text,
  thumbnail_url text,
  thumbnail_storage_path text,
  thumbnail_generated boolean not null default false,
  status public.challenge_status not null default 'DRAFT',
  is_active boolean not null default true,
  share_count bigint not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint challenges_title_not_blank check (btrim(title) <> ''),
  constraint challenges_entry_fee_non_negative check (entry_fee >= 0),
  constraint challenges_max_participants_positive check (max_participants is null or max_participants > 0),
  constraint challenges_winner_count_positive check (winner_count is null or winner_count > 0),
  constraint challenges_date_order check (submit_due_date <= vote_start_date and vote_start_date <= vote_end_date)
);

create index idx_challenges_user_id on public.challenges(user_id);
create index idx_challenges_status_dates on public.challenges(status, submit_due_date, vote_start_date, vote_end_date) where deleted_at is null;
create index idx_challenges_audience on public.challenges(audience) where deleted_at is null;
create index idx_challenges_deleted_at on public.challenges(deleted_at);

create trigger trg_challenges_updated_at
before update on public.challenges
for each row execute function public.set_updated_at();

create table public.challenge_submissions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  video_url text not null,
  video_storage_path text not null,
  thumbnail_url text,
  thumbnail_storage_path text,
  thumbnail_generated boolean not null default false,
  status public.challenge_submission_status not null default 'PENDING',
  rank integer,
  is_winner boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint challenge_submissions_unique unique (challenge_id, user_id),
  constraint challenge_submissions_rank_positive check (rank is null or rank > 0)
);

create index idx_challenge_submissions_challenge_id on public.challenge_submissions(challenge_id);
create index idx_challenge_submissions_user_id on public.challenge_submissions(user_id);
create index idx_challenge_submissions_status on public.challenge_submissions(status);

create trigger trg_challenge_submissions_updated_at
before update on public.challenge_submissions
for each row execute function public.set_updated_at();

create table public.challenge_votes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  submission_id uuid not null references public.challenge_submissions(id) on delete cascade,
  voter_id uuid not null references public.user_profiles(id) on delete cascade,
  rating integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint challenge_votes_unique_per_challenge_voter unique (challenge_id, voter_id),
  constraint challenge_votes_rating_range check (rating between 1 and 5)
);

create index idx_challenge_votes_challenge_id on public.challenge_votes(challenge_id);
create index idx_challenge_votes_submission_id on public.challenge_votes(submission_id);
create index idx_challenge_votes_voter_id on public.challenge_votes(voter_id);

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

create trigger trg_validate_challenge_submission
before insert on public.challenge_submissions
for each row execute function public.validate_challenge_submission();

create or replace function public.validate_challenge_vote()
returns trigger
language plpgsql
as $$
declare
  _challenge public.challenges;
  _submission_owner uuid;
begin
  select * into _challenge from public.challenges where id = new.challenge_id and deleted_at is null;
  if not found then
    raise exception 'Challenge not found';
  end if;

  if timezone('utc', now()) < _challenge.vote_start_date or timezone('utc', now()) > _challenge.vote_end_date then
    raise exception 'Voting is not currently open';
  end if;

  if _challenge.status not in ('VOTING', 'ACTIVE') then
    raise exception 'Challenge is not in a votable state';
  end if;

  select cs.user_id into _submission_owner
  from public.challenge_submissions cs
  where cs.id = new.submission_id
    and cs.challenge_id = new.challenge_id;

  if _submission_owner is null then
    raise exception 'Submission does not belong to challenge';
  end if;

  if _submission_owner = new.voter_id then
    raise exception 'Users cannot vote for themselves';
  end if;

  return new;
end;
$$;

create trigger trg_validate_challenge_vote
before insert on public.challenge_votes
for each row execute function public.validate_challenge_vote();

create or replace function public.calculate_challenge_rankings(_challenge_id uuid)
returns table (
  submission_id uuid,
  participant_id uuid,
  average_rating numeric,
  rank integer,
  is_winner boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  _winner_count integer;
begin
  select coalesce(winner_count, 1)
  into _winner_count
  from public.challenges
  where id = _challenge_id;

  with ranked as (
    select
      cs.id as submission_id,
      cs.user_id as participant_id,
      coalesce(avg(cv.rating), 0)::numeric(10,2) as average_rating,
      dense_rank() over (order by coalesce(avg(cv.rating), 0) desc, min(cs.created_at) asc) as computed_rank
    from public.challenge_submissions cs
    left join public.challenge_votes cv on cv.submission_id = cs.id
    where cs.challenge_id = _challenge_id
      and cs.status = 'APPROVED'
    group by cs.id, cs.user_id
  ), updated as (
    update public.challenge_submissions cs
    set
      rank = r.computed_rank,
      is_winner = (r.computed_rank <= _winner_count),
      updated_at = timezone('utc', now())
    from ranked r
    where cs.id = r.submission_id
    returning cs.id, cs.user_id, r.average_rating, cs.rank, cs.is_winner
  )
  select * from updated;
end;
$$;

-- =========================================================
-- 7) TEAM SYSTEM
-- =========================================================
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_lower text generated always as (lower(name)) stored,
  short_name text,
  description text,
  owner_id uuid not null references public.user_profiles(id) on delete restrict,
  is_public boolean not null default true,
  logo_url text,
  country text,
  city text,
  founded_at date,
  primary_color text,
  secondary_color text,
  matches_played integer not null default 0,
  wins integer not null default 0,
  draws integer not null default 0,
  losses integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint teams_name_not_blank check (btrim(name) <> ''),
  constraint teams_stats_non_negative check (
    matches_played >= 0 and wins >= 0 and draws >= 0 and losses >= 0
  )
);

create index idx_teams_name_lower on public.teams(name_lower) where deleted_at is null;
create index idx_teams_owner_id on public.teams(owner_id);
create index idx_teams_country_city on public.teams(country, city) where deleted_at is null;
create index idx_teams_deleted_at on public.teams(deleted_at);

create trigger trg_teams_updated_at
before update on public.teams
for each row execute function public.set_updated_at();

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  role public.team_role not null default 'PLAYER',
  jersey_number integer,
  joined_at timestamptz not null default timezone('utc', now()),
  constraint team_members_unique unique (team_id, user_id),
  constraint team_members_jersey_positive check (jersey_number is null or jersey_number > 0)
);

create index idx_team_members_team_id on public.team_members(team_id);
create index idx_team_members_user_id on public.team_members(user_id);
create unique index idx_team_members_one_owner_per_team
on public.team_members(team_id)
where role = 'OWNER';

create table public.team_memberships (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  type public.team_membership_type not null,
  status public.team_membership_status not null default 'PENDING',
  initiated_by uuid not null references public.user_profiles(id) on delete restrict,
  message text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint team_memberships_unique_pending unique (team_id, user_id, type, initiated_by)
);

create index idx_team_memberships_team_id_status on public.team_memberships(team_id, status);
create index idx_team_memberships_user_id_status on public.team_memberships(user_id, status);

create trigger trg_team_memberships_updated_at
before update on public.team_memberships
for each row execute function public.set_updated_at();

create or replace function public.create_team_owner_membership()
returns trigger
language plpgsql
as $$
begin
  insert into public.team_members (team_id, user_id, role)
  values (new.id, new.owner_id, 'OWNER')
  on conflict (team_id, user_id) do update set role = 'OWNER';
  return new;
end;
$$;

create trigger trg_create_team_owner_membership
after insert on public.teams
for each row execute function public.create_team_owner_membership();

create or replace function public.apply_team_membership_acceptance()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'ACCEPTED' and old.status is distinct from new.status then
    insert into public.team_members (team_id, user_id, role)
    values (new.team_id, new.user_id, 'PLAYER')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger trg_apply_team_membership_acceptance
after update on public.team_memberships
for each row execute function public.apply_team_membership_acceptance();

-- =========================================================
-- 8) TOURNAMENT SYSTEM
-- =========================================================
create table public.tournaments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type public.tournament_type not null,
  created_by uuid not null references public.user_profiles(id) on delete restrict,
  status public.tournament_status not null default 'DRAFT',
  max_teams integer,
  start_date timestamptz,
  end_date timestamptz,
  rules jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint tournaments_name_not_blank check (btrim(name) <> ''),
  constraint tournaments_max_teams_positive check (max_teams is null or max_teams > 0),
  constraint tournaments_date_order check (start_date is null or end_date is null or start_date <= end_date)
);

create index idx_tournaments_created_by on public.tournaments(created_by);
create index idx_tournaments_type_status on public.tournaments(type, status) where deleted_at is null;
create index idx_tournaments_deleted_at on public.tournaments(deleted_at);

create trigger trg_tournaments_updated_at
before update on public.tournaments
for each row execute function public.set_updated_at();

-- RLS helpers that reference core tables (must run after those tables exist; SQL functions are validated at create time)
create or replace function public.are_friends(_user_a uuid, _user_b uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.friendships f
    where f.user_id = _user_a
      and f.friend_id = _user_b
  );
$$;

create or replace function public.is_team_admin_or_owner(_team_id uuid, _user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = _team_id
      and tm.user_id = _user_id
      and tm.role in ('OWNER', 'ADMIN')
  );
$$;

create or replace function public.is_tournament_creator(_tournament_id uuid, _user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.tournaments t
    where t.id = _tournament_id
      and t.created_by = _user_id
  );
$$;

create or replace function public.is_video_visible_to_user(_video_id uuid, _viewer_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.videos v
    where v.id = _video_id
      and v.deleted_at is null
      and (
        v.user_id = _viewer_id
        or v.visibility = 'PUBLIC'
        or (v.visibility = 'FRIENDS' and public.are_friends(v.user_id, _viewer_id))
      )
  );
$$;

create or replace function public.is_challenge_visible_to_user(_challenge_id uuid, _viewer_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.challenges c
    left join public.user_profiles owner on owner.id = c.user_id
    left join public.user_profiles viewer on viewer.id = _viewer_id
    where c.id = _challenge_id
      and c.deleted_at is null
      and (
        c.user_id = _viewer_id
        or c.audience = 'WORLDWIDE'
        or (c.audience = 'FRIENDS' and public.are_friends(c.user_id, _viewer_id))
        or (c.audience = 'CITY' and owner.city is not null and viewer.city = owner.city)
        or (c.audience = 'COUNTRY' and owner.country is not null and viewer.country = owner.country)
      )
  );
$$;

create table public.tournament_teams (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  status public.tournament_team_status not null,
  joined_at timestamptz,
  constraint tournament_teams_unique unique (tournament_id, team_id)
);

create index idx_tournament_teams_tournament_id on public.tournament_teams(tournament_id, status);
create index idx_tournament_teams_team_id on public.tournament_teams(team_id);

create table public.tournament_invitations (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  invited_by uuid not null references public.user_profiles(id) on delete restrict,
  status public.invitation_status not null default 'PENDING',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tournament_invitations_unique unique (tournament_id, team_id)
);

create index idx_tournament_invitations_tournament_id on public.tournament_invitations(tournament_id, status);
create index idx_tournament_invitations_team_id on public.tournament_invitations(team_id, status);

create trigger trg_tournament_invitations_updated_at
before update on public.tournament_invitations
for each row execute function public.set_updated_at();

create table public.tournament_join_requests (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  requested_by uuid not null references public.user_profiles(id) on delete restrict,
  status public.invitation_status not null default 'PENDING',
  created_at timestamptz not null default timezone('utc', now()),
  constraint tournament_join_requests_unique unique (tournament_id, team_id)
);

create index idx_tournament_join_requests_tournament_id on public.tournament_join_requests(tournament_id, status);
create index idx_tournament_join_requests_team_id on public.tournament_join_requests(team_id, status);

create table public.knockout_rounds (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  name text not null,
  round_number integer not null,
  constraint knockout_rounds_unique unique (tournament_id, round_number),
  constraint knockout_rounds_round_positive check (round_number > 0)
);

create index idx_knockout_rounds_tournament_id on public.knockout_rounds(tournament_id);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  home_team_id uuid not null references public.teams(id) on delete restrict,
  away_team_id uuid not null references public.teams(id) on delete restrict,
  match_date timestamptz,
  venue text,
  status public.match_status not null default 'SCHEDULED',
  home_score integer not null default 0,
  away_score integer not null default 0,
  winner_team_id uuid references public.teams(id) on delete restrict,
  round_id uuid references public.knockout_rounds(id) on delete set null,
  duration_minutes integer,
  is_extra_time boolean not null default false,
  is_penalty_decider boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint matches_distinct_teams check (home_team_id <> away_team_id),
  constraint matches_scores_non_negative check (home_score >= 0 and away_score >= 0),
  constraint matches_duration_positive check (duration_minutes is null or duration_minutes > 0),
  constraint matches_winner_is_participant check (
    winner_team_id is null or winner_team_id in (home_team_id, away_team_id)
  )
);

create index idx_matches_tournament_id_date on public.matches(tournament_id, match_date);
create index idx_matches_home_team_id on public.matches(home_team_id);
create index idx_matches_away_team_id on public.matches(away_team_id);
create index idx_matches_round_id on public.matches(round_id);

create trigger trg_matches_updated_at
before update on public.matches
for each row execute function public.set_updated_at();

create table public.knockout_match_links (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  next_match_id uuid not null references public.matches(id) on delete cascade,
  position integer not null,
  constraint knockout_match_links_unique unique (match_id),
  constraint knockout_match_links_position_check check (position in (1, 2))
);

create index idx_knockout_match_links_next_match_id on public.knockout_match_links(next_match_id);

create table public.standings (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  played integer not null default 0,
  wins integer not null default 0,
  draws integer not null default 0,
  losses integer not null default 0,
  goals_for integer not null default 0,
  goals_against integer not null default 0,
  goal_difference integer not null default 0,
  points integer not null default 0,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint standings_unique unique (tournament_id, team_id),
  constraint standings_non_negative check (
    played >= 0 and wins >= 0 and draws >= 0 and losses >= 0 and
    goals_for >= 0 and goals_against >= 0 and points >= 0
  )
);

create index idx_standings_tournament_points on public.standings(tournament_id, points desc, goal_difference desc, goals_for desc);

create table public.league_fixtures (
  id uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade,
  round integer not null,
  constraint league_fixtures_unique_match unique (match_id),
  constraint league_fixtures_round_positive check (round > 0)
);

create index idx_league_fixtures_tournament_id_round on public.league_fixtures(tournament_id, round);

create table public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid references public.user_profiles(id) on delete set null,
  event_type public.match_event_type not null,
  minute integer not null,
  metadata jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint match_events_minute_non_negative check (minute >= 0)
);

create index idx_match_events_match_id on public.match_events(match_id, minute);
create index idx_match_events_player_id on public.match_events(player_id);

create or replace function public.sync_tournament_team_from_invitation()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'ACCEPTED' and old.status is distinct from new.status then
    insert into public.tournament_teams (tournament_id, team_id, status, joined_at)
    values (new.tournament_id, new.team_id, 'APPROVED', timezone('utc', now()))
    on conflict (tournament_id, team_id) do update
    set status = 'APPROVED', joined_at = excluded.joined_at;
  end if;
  return new;
end;
$$;

create trigger trg_tournament_invitations_sync_team
after update on public.tournament_invitations
for each row execute function public.sync_tournament_team_from_invitation();

create or replace function public.sync_tournament_team_from_join_request()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'ACCEPTED' then
    insert into public.tournament_teams (tournament_id, team_id, status, joined_at)
    values (new.tournament_id, new.team_id, 'APPROVED', timezone('utc', now()))
    on conflict (tournament_id, team_id) do update
    set status = 'APPROVED', joined_at = excluded.joined_at;
  end if;
  return new;
end;
$$;

create trigger trg_tournament_join_requests_sync_team
after insert or update on public.tournament_join_requests
for each row execute function public.sync_tournament_team_from_join_request();

create or replace function public.recalculate_standings(_tournament_id uuid)
returns table (
  team_id uuid,
  played integer,
  wins integer,
  draws integer,
  losses integer,
  goals_for integer,
  goals_against integer,
  goal_difference integer,
  points integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.standings where tournament_id = _tournament_id;

  insert into public.standings (
    tournament_id, team_id, played, wins, draws, losses,
    goals_for, goals_against, goal_difference, points, updated_at
  )
  with completed_matches as (
    select *
    from public.matches m
    where m.tournament_id = _tournament_id
      and m.status = 'COMPLETED'
  ), per_team as (
    select
      x.team_id,
      count(*)::int as played,
      count(*) filter (where x.result = 'W')::int as wins,
      count(*) filter (where x.result = 'D')::int as draws,
      count(*) filter (where x.result = 'L')::int as losses,
      sum(x.gf)::int as goals_for,
      sum(x.ga)::int as goals_against,
      (sum(x.gf) - sum(x.ga))::int as goal_difference,
      sum(case when x.result = 'W' then coalesce((t.rules->>'win_points')::int, 3)
               when x.result = 'D' then coalesce((t.rules->>'draw_points')::int, 1)
               else 0 end)::int as points
    from (
      select
        m.home_team_id as team_id,
        m.home_score as gf,
        m.away_score as ga,
        case when m.home_score > m.away_score then 'W'
             when m.home_score = m.away_score then 'D'
             else 'L' end as result,
        m.tournament_id
      from completed_matches m
      union all
      select
        m.away_team_id as team_id,
        m.away_score as gf,
        m.home_score as ga,
        case when m.away_score > m.home_score then 'W'
             when m.away_score = m.home_score then 'D'
             else 'L' end as result,
        m.tournament_id
      from completed_matches m
    ) x
    join public.tournaments t on t.id = x.tournament_id
    group by x.team_id
  )
  select
    _tournament_id,
    pt.team_id,
    pt.played,
    pt.wins,
    pt.draws,
    pt.losses,
    pt.goals_for,
    pt.goals_against,
    pt.goal_difference,
    pt.points,
    timezone('utc', now())
  from per_team pt;

  return query
  select s.team_id, s.played, s.wins, s.draws, s.losses, s.goals_for, s.goals_against, s.goal_difference, s.points
  from public.standings s
  where s.tournament_id = _tournament_id
  order by s.points desc, s.goal_difference desc, s.goals_for desc, s.team_id;
end;
$$;

-- =========================================================
-- 9) SUBSCRIPTIONS
-- =========================================================
create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  price numeric(14,2) not null,
  currency text not null,
  max_challenges_per_month integer,
  max_teams integer,
  max_tournaments_per_month integer,
  features jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint subscription_plans_name_not_blank check (btrim(name) <> ''),
  constraint subscription_plans_price_non_negative check (price >= 0),
  constraint subscription_plan_limits_non_negative check (
    max_challenges_per_month is null or max_challenges_per_month >= 0
  )
);

create table public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  status public.subscription_status not null,
  started_at timestamptz not null,
  expires_at timestamptz,
  auto_renew boolean not null default false,
  provider public.subscription_provider,
  provider_reference_id text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint user_subscriptions_dates check (expires_at is null or started_at <= expires_at)
);

create index idx_user_subscriptions_user_id on public.user_subscriptions(user_id, created_at desc);
create index idx_user_subscriptions_plan_id on public.user_subscriptions(plan_id);
create unique index idx_user_subscriptions_one_active_per_user
on public.user_subscriptions(user_id)
where status = 'ACTIVE';

create trigger trg_user_subscriptions_updated_at
before update on public.user_subscriptions
for each row execute function public.set_updated_at();

create or replace function public.get_current_user_entitlements(_user_id uuid)
returns table (
  plan_name text,
  max_challenges_per_month integer,
  max_teams integer,
  max_tournaments_per_month integer,
  features jsonb,
  subscription_status public.subscription_status,
  expires_at timestamptz
)
language sql
stable
as $$
  select
    sp.name,
    sp.max_challenges_per_month,
    sp.max_teams,
    sp.max_tournaments_per_month,
    sp.features,
    us.status,
    us.expires_at
  from public.user_subscriptions us
  join public.subscription_plans sp on sp.id = us.plan_id
  where us.user_id = _user_id
    and us.status = 'ACTIVE'
  order by us.started_at desc
  limit 1;
$$;

-- =========================================================
-- 10) WALLET / TRANSACTIONS
-- =========================================================
create table public.user_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.user_profiles(id) on delete cascade,
  balance numeric(14,2) not null default 0,
  locked_balance numeric(14,2) not null default 0,
  currency text not null,
  total_earned numeric(14,2) not null default 0,
  total_spent numeric(14,2) not null default 0,
  status public.wallet_status not null default 'ACTIVE',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint user_wallets_balance_non_negative check (balance >= 0),
  constraint user_wallets_locked_non_negative check (locked_balance >= 0),
  constraint user_wallets_totals_non_negative check (total_earned >= 0 and total_spent >= 0)
);

create trigger trg_user_wallets_updated_at
before update on public.user_wallets
for each row execute function public.set_updated_at();

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  type public.transaction_type not null,
  amount numeric(14,2) not null,
  currency text not null,
  status public.transaction_status not null default 'PENDING',
  reference_id uuid,
  reference_type public.transaction_reference_type,
  provider text,
  provider_tx_id text,
  description text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint transactions_amount_positive check (amount > 0)
);

create index idx_transactions_user_id_created_at on public.transactions(user_id, created_at desc);
create index idx_transactions_reference on public.transactions(reference_type, reference_id);
create index idx_transactions_status on public.transactions(status);
create index idx_transactions_provider_tx_id on public.transactions(provider_tx_id);

create trigger trg_transactions_updated_at
before update on public.transactions
for each row execute function public.set_updated_at();

create table public.wallet_transaction_logs (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.user_wallets(id) on delete cascade,
  transaction_id uuid not null unique references public.transactions(id) on delete cascade,
  balance_before numeric(14,2) not null,
  balance_after numeric(14,2) not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_wallet_transaction_logs_wallet_id on public.wallet_transaction_logs(wallet_id, created_at desc);

create table public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  transaction_id uuid references public.transactions(id) on delete set null,
  provider text not null,
  status text not null,
  response jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index idx_payment_attempts_user_id on public.payment_attempts(user_id, created_at desc);
create index idx_payment_attempts_transaction_id on public.payment_attempts(transaction_id);

create or replace function public.apply_completed_transaction(_transaction_id uuid)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  _tx public.transactions;
  _wallet public.user_wallets;
  _before numeric(14,2);
  _after numeric(14,2);
begin
  select * into _tx
  from public.transactions
  where id = _transaction_id
  for update;

  if not found then
    raise exception 'Transaction not found';
  end if;

  if _tx.status <> 'COMPLETED' then
    raise exception 'Only COMPLETED transactions can be applied';
  end if;

  if exists (
    select 1 from public.wallet_transaction_logs where transaction_id = _tx.id
  ) then
    return _tx;
  end if;

  select * into _wallet
  from public.user_wallets
  where user_id = _tx.user_id
  for update;

  if not found then
    raise exception 'Wallet not found';
  end if;

  _before := _wallet.balance;

  if _tx.type in ('DEPOSIT', 'CHALLENGE_PRIZE', 'REFUND') then
    _after := _wallet.balance + _tx.amount;
    update public.user_wallets
    set
      balance = _after,
      total_earned = total_earned + _tx.amount,
      updated_at = timezone('utc', now())
    where id = _wallet.id;
  elsif _tx.type in ('WITHDRAWAL', 'CHALLENGE_ENTRY', 'SUBSCRIPTION_PAYMENT') then
    if _wallet.balance < _tx.amount then
      raise exception 'Insufficient wallet balance';
    end if;
    _after := _wallet.balance - _tx.amount;
    update public.user_wallets
    set
      balance = _after,
      total_spent = total_spent + _tx.amount,
      updated_at = timezone('utc', now())
    where id = _wallet.id;
  else
    raise exception 'Unsupported transaction type';
  end if;

  insert into public.wallet_transaction_logs (
    wallet_id,
    transaction_id,
    balance_before,
    balance_after
  ) values (
    _wallet.id,
    _tx.id,
    _before,
    _after
  );

  return _tx;
end;
$$;

-- =========================================================
-- 11) NOTIFICATIONS
-- =========================================================
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.user_profiles(id) on delete cascade,
  actor_id uuid references public.user_profiles(id) on delete set null,
  type public.notification_type not null,
  title text not null,
  body text not null,
  reference_id uuid,
  reference_type public.notification_reference_type,
  image_url text,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint notifications_title_not_blank check (btrim(title) <> ''),
  constraint notifications_body_not_blank check (btrim(body) <> ''),
  constraint notifications_read_consistency check (
    (is_read = false and read_at is null) or (is_read = true)
  )
);

create index idx_notifications_recipient_unread on public.notifications(recipient_id, is_read, created_at desc) where deleted_at is null;
create index idx_notifications_reference on public.notifications(reference_type, reference_id);
create index idx_notifications_deleted_at on public.notifications(deleted_at);

create table public.notification_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.user_profiles(id) on delete cascade,
  video_likes boolean not null default true,
  video_comments boolean not null default true,
  friend_requests boolean not null default true,
  challenge_updates boolean not null default true,
  team_updates boolean not null default true,
  tournament_updates boolean not null default true,
  payments boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger trg_notification_settings_updated_at
before update on public.notification_settings
for each row execute function public.set_updated_at();

create or replace function public.refresh_unread_notification_count(_user_id uuid)
returns void
language plpgsql
as $$
begin
  update public.user_profiles
  set unread_notifications_count = (
    select count(*)::int
    from public.notifications n
    where n.recipient_id = _user_id
      and n.is_read = false
      and n.deleted_at is null
  )
  where id = _user_id;
end;
$$;

create or replace function public.trg_refresh_unread_notification_count()
returns trigger
language plpgsql
as $$
begin
  perform public.refresh_unread_notification_count(coalesce(new.recipient_id, old.recipient_id));
  return coalesce(new, old);
end;
$$;

create trigger trg_notifications_refresh_unread_ins_upd_del
after insert or update or delete on public.notifications
for each row execute function public.trg_refresh_unread_notification_count();

create or replace function public.create_notification(
  _recipient_id uuid,
  _actor_id uuid,
  _type public.notification_type,
  _title text,
  _body text,
  _reference_id uuid default null,
  _reference_type public.notification_reference_type default null,
  _image_url text default null
)
returns public.notifications
language plpgsql
security definer
set search_path = public
as $$
declare
  _row public.notifications;
begin
  insert into public.notifications (
    recipient_id, actor_id, type, title, body, reference_id, reference_type, image_url
  ) values (
    _recipient_id, _actor_id, _type, _title, _body, _reference_id, _reference_type, _image_url
  )
  returning * into _row;

  return _row;
end;
$$;

-- =========================================================
-- 12) DEVICES / PUSH
-- =========================================================
create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles(id) on delete cascade,
  device_id text not null unique,
  fcm_token text unique,
  platform public.device_platform not null,
  device_name text,
  device_model text,
  os_version text,
  app_version text,
  app_build_number text,
  locale text,
  timezone text,
  push_enabled boolean not null default true,
  is_active boolean not null default true,
  last_seen_at timestamptz,
  last_notification_sent_at timestamptz,
  ip_address inet,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index idx_user_devices_user_id_active on public.user_devices(user_id, is_active);
create index idx_user_devices_fcm_token on public.user_devices(fcm_token) where fcm_token is not null;

create trigger trg_user_devices_updated_at
before update on public.user_devices
for each row execute function public.set_updated_at();

create or replace function public.upsert_user_device(
  _device_id text,
  _fcm_token text,
  _platform public.device_platform,
  _device_name text default null,
  _device_model text default null,
  _os_version text default null,
  _app_version text default null,
  _app_build_number text default null,
  _locale text default null,
  _timezone text default null,
  _ip_address inet default null
)
returns public.user_devices
language plpgsql
security definer
set search_path = public
as $$
declare
  _row public.user_devices;
begin
  insert into public.user_devices (
    user_id,
    device_id,
    fcm_token,
    platform,
    device_name,
    device_model,
    os_version,
    app_version,
    app_build_number,
    locale,
    timezone,
    push_enabled,
    is_active,
    last_seen_at,
    ip_address
  ) values (
    auth.uid(),
    _device_id,
    _fcm_token,
    _platform,
    _device_name,
    _device_model,
    _os_version,
    _app_version,
    _app_build_number,
    _locale,
    _timezone,
    true,
    true,
    timezone('utc', now()),
    _ip_address
  )
  on conflict (device_id)
  do update set
    user_id = excluded.user_id,
    fcm_token = excluded.fcm_token,
    platform = excluded.platform,
    device_name = excluded.device_name,
    device_model = excluded.device_model,
    os_version = excluded.os_version,
    app_version = excluded.app_version,
    app_build_number = excluded.app_build_number,
    locale = excluded.locale,
    timezone = excluded.timezone,
    push_enabled = true,
    is_active = true,
    last_seen_at = timezone('utc', now()),
    ip_address = excluded.ip_address,
    updated_at = timezone('utc', now())
  returning * into _row;

  return _row;
end;
$$;

-- =========================================================
-- 13) STORAGE BUCKETS (OPTIONAL BUT READY FOR SUPABASE)
-- =========================================================
insert into storage.buckets (id, name, public)
values
  ('videos', 'videos', true),
  ('thumbnails', 'thumbnails', true),
  ('challenge_videos', 'challenge_videos', true),
  ('team_logos', 'team_logos', true),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- =========================================================
-- 14) RLS ENABLEMENT
-- =========================================================
alter table public.user_profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.blocked_users enable row level security;
alter table public.videos enable row level security;
alter table public.video_likes enable row level security;
alter table public.video_comments enable row level security;
alter table public.video_favorites enable row level security;
alter table public.video_ratings enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_submissions enable row level security;
alter table public.challenge_votes enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_memberships enable row level security;
alter table public.tournaments enable row level security;
alter table public.tournament_teams enable row level security;
alter table public.tournament_invitations enable row level security;
alter table public.tournament_join_requests enable row level security;
alter table public.knockout_rounds enable row level security;
alter table public.matches enable row level security;
alter table public.knockout_match_links enable row level security;
alter table public.standings enable row level security;
alter table public.league_fixtures enable row level security;
alter table public.match_events enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.user_subscriptions enable row level security;
alter table public.user_wallets enable row level security;
alter table public.transactions enable row level security;
alter table public.wallet_transaction_logs enable row level security;
alter table public.payment_attempts enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_settings enable row level security;
alter table public.user_devices enable row level security;

-- =========================================================
-- 15) RLS POLICIES
-- =========================================================
-- user_profiles
create policy "profiles are publicly readable if not soft-deleted"
on public.user_profiles
for select
using (deleted_at is null);

create policy "users can insert their own profile"
on public.user_profiles
for insert
with check (auth.uid() = id);

create policy "users can update their own profile"
on public.user_profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- friend_requests
create policy "users can view their own friend requests"
on public.friend_requests
for select
using (auth.uid() in (sender_id, receiver_id));

create policy "users can create friend requests as sender"
on public.friend_requests
for insert
with check (auth.uid() = sender_id);

create policy "sender or receiver can update friend request"
on public.friend_requests
for update
using (auth.uid() in (sender_id, receiver_id))
with check (auth.uid() in (sender_id, receiver_id));

create policy "sender or receiver can delete friend request"
on public.friend_requests
for delete
using (auth.uid() in (sender_id, receiver_id));

-- friendships
create policy "users can view their own friendships"
on public.friendships
for select
using (auth.uid() = user_id);

create policy "users can delete their own friendship edge"
on public.friendships
for delete
using (auth.uid() = user_id);

-- blocked_users
create policy "users can manage their own blocks"
on public.blocked_users
for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- videos
create policy "videos visible by privacy rule"
on public.videos
for select
using (
  deleted_at is null
  and (
    visibility = 'PUBLIC'
    or user_id = auth.uid()
    or (visibility = 'FRIENDS' and public.are_friends(user_id, auth.uid()))
  )
);

create policy "users can create their own videos"
on public.videos
for insert
with check (auth.uid() = user_id);

create policy "users can update their own videos"
on public.videos
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users can delete their own videos"
on public.videos
for delete
using (auth.uid() = user_id);

-- video_likes
create policy "video likes are visible when parent video is visible"
on public.video_likes
for select
using (public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can manage their own likes"
on public.video_likes
for insert
with check (auth.uid() = user_id and public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can delete their own likes"
on public.video_likes
for delete
using (auth.uid() = user_id);

-- video_comments
create policy "video comments are visible when parent video is visible"
on public.video_comments
for select
using (deleted_at is null and public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can create their own comments"
on public.video_comments
for insert
with check (auth.uid() = user_id and public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can update their own comments"
on public.video_comments
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users can delete their own comments"
on public.video_comments
for delete
using (auth.uid() = user_id);

-- video_favorites
create policy "users can view their own favorites"
on public.video_favorites
for select
using (auth.uid() = user_id);

create policy "users can create their own favorites"
on public.video_favorites
for insert
with check (auth.uid() = user_id and public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can delete their own favorites"
on public.video_favorites
for delete
using (auth.uid() = user_id);

-- video_ratings
create policy "video ratings visible when parent video is visible"
on public.video_ratings
for select
using (public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can create their own ratings"
on public.video_ratings
for insert
with check (auth.uid() = user_id and public.is_video_visible_to_user(video_id, auth.uid()));

create policy "users can update their own ratings"
on public.video_ratings
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users can delete their own ratings"
on public.video_ratings
for delete
using (auth.uid() = user_id);

-- challenges
create policy "challenges visible by audience rule"
on public.challenges
for select
using (deleted_at is null and public.is_challenge_visible_to_user(id, auth.uid()));

create policy "users can create their own challenges"
on public.challenges
for insert
with check (auth.uid() = user_id);

create policy "users can update their own challenges"
on public.challenges
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "users can delete their own challenges"
on public.challenges
for delete
using (auth.uid() = user_id);

-- challenge_submissions
create policy "challenge submissions visible if challenge is visible"
on public.challenge_submissions
for select
using (public.is_challenge_visible_to_user(challenge_id, auth.uid()));

create policy "users can create their own challenge submissions"
on public.challenge_submissions
for insert
with check (auth.uid() = user_id and public.is_challenge_visible_to_user(challenge_id, auth.uid()));

create policy "users can update their own pending submissions or owner can moderate"
on public.challenge_submissions
for update
using (
  auth.uid() = user_id
  or exists (
    select 1 from public.challenges c where c.id = challenge_id and c.user_id = auth.uid()
  )
)
with check (
  auth.uid() = user_id
  or exists (
    select 1 from public.challenges c where c.id = challenge_id and c.user_id = auth.uid()
  )
);

create policy "users can delete their own challenge submissions"
on public.challenge_submissions
for delete
using (auth.uid() = user_id);

-- challenge_votes
create policy "challenge votes visible if challenge is visible"
on public.challenge_votes
for select
using (public.is_challenge_visible_to_user(challenge_id, auth.uid()));

create policy "users can create their own challenge votes"
on public.challenge_votes
for insert
with check (auth.uid() = voter_id and public.is_challenge_visible_to_user(challenge_id, auth.uid()));

create policy "users can delete their own challenge votes"
on public.challenge_votes
for delete
using (auth.uid() = voter_id);

-- teams
create policy "public teams are visible; private teams visible to members"
on public.teams
for select
using (
  deleted_at is null and (
    is_public = true
    or owner_id = auth.uid()
    or exists (
      select 1 from public.team_members tm where tm.team_id = id and tm.user_id = auth.uid()
    )
  )
);

create policy "users can create teams they own"
on public.teams
for insert
with check (auth.uid() = owner_id);

create policy "team owner can update team"
on public.teams
for update
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

create policy "team owner can delete team"
on public.teams
for delete
using (auth.uid() = owner_id);

-- team_members
create policy "team members are visible to authorized team viewers"
on public.team_members
for select
using (
  exists (
    select 1
    from public.teams t
    where t.id = team_id
      and t.deleted_at is null
      and (
        t.is_public = true
        or t.owner_id = auth.uid()
        or exists (
          select 1 from public.team_members tm2 where tm2.team_id = team_id and tm2.user_id = auth.uid()
        )
      )
  )
);

create policy "team owner admin can manage members"
on public.team_members
for insert
with check (public.is_team_admin_or_owner(team_id, auth.uid()));

create policy "team owner admin can update members"
on public.team_members
for update
using (public.is_team_admin_or_owner(team_id, auth.uid()))
with check (public.is_team_admin_or_owner(team_id, auth.uid()));

create policy "team owner admin can delete members or user can remove self if not owner"
on public.team_members
for delete
using (
  public.is_team_admin_or_owner(team_id, auth.uid())
  or (auth.uid() = user_id and role <> 'OWNER')
);

-- team_memberships
create policy "users can view memberships they are involved in or admins can view"
on public.team_memberships
for select
using (
  auth.uid() in (user_id, initiated_by)
  or public.is_team_admin_or_owner(team_id, auth.uid())
);

create policy "team admins can invite, users can request to join"
on public.team_memberships
for insert
with check (
  (type = 'INVITE' and public.is_team_admin_or_owner(team_id, auth.uid()) and initiated_by = auth.uid())
  or (type = 'REQUEST' and auth.uid() = user_id and initiated_by = auth.uid())
);

create policy "team admins or target user can update membership requests"
on public.team_memberships
for update
using (
  public.is_team_admin_or_owner(team_id, auth.uid())
  or auth.uid() = user_id
)
with check (
  public.is_team_admin_or_owner(team_id, auth.uid())
  or auth.uid() = user_id
);

-- tournaments
create policy "tournaments are readable when not soft-deleted"
on public.tournaments
for select
using (deleted_at is null);

create policy "users can create tournaments they own"
on public.tournaments
for insert
with check (auth.uid() = created_by);

create policy "tournament creator can update"
on public.tournaments
for update
using (auth.uid() = created_by)
with check (auth.uid() = created_by);

create policy "tournament creator can delete"
on public.tournaments
for delete
using (auth.uid() = created_by);

-- tournament_teams
create policy "tournament teams are readable"
on public.tournament_teams
for select
using (exists (select 1 from public.tournaments t where t.id = tournament_id and t.deleted_at is null));

create policy "tournament creator manages tournament teams"
on public.tournament_teams
for all
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- tournament_invitations
create policy "tournament invitations visible to tournament creator or team admins"
on public.tournament_invitations
for select
using (
  public.is_tournament_creator(tournament_id, auth.uid())
  or exists (
    select 1 from public.team_members tm where tm.team_id = team_id and tm.user_id = auth.uid() and tm.role in ('OWNER', 'ADMIN')
  )
);

create policy "tournament creator can manage invitations"
on public.tournament_invitations
for all
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- tournament_join_requests
create policy "join requests visible to creator or requesting team admins"
on public.tournament_join_requests
for select
using (
  public.is_tournament_creator(tournament_id, auth.uid())
  or exists (
    select 1 from public.team_members tm where tm.team_id = team_id and tm.user_id = auth.uid() and tm.role in ('OWNER', 'ADMIN')
  )
);

create policy "team admins can create join requests"
on public.tournament_join_requests
for insert
with check (
  requested_by = auth.uid()
  and exists (
    select 1 from public.team_members tm where tm.team_id = team_id and tm.user_id = auth.uid() and tm.role in ('OWNER', 'ADMIN')
  )
);

create policy "tournament creator can update join requests"
on public.tournament_join_requests
for update
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- knockout_rounds
create policy "knockout rounds are readable"
on public.knockout_rounds
for select
using (exists (select 1 from public.tournaments t where t.id = tournament_id and t.deleted_at is null));

create policy "tournament creator manages knockout rounds"
on public.knockout_rounds
for all
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- matches
create policy "matches are readable"
on public.matches
for select
using (exists (select 1 from public.tournaments t where t.id = tournament_id and t.deleted_at is null));

create policy "tournament creator manages matches"
on public.matches
for all
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- knockout_match_links
create policy "knockout match links are readable"
on public.knockout_match_links
for select
using (true);

create policy "authorized tournament creator manages knockout match links"
on public.knockout_match_links
for all
using (
  exists (
    select 1
    from public.matches m
    join public.tournaments t on t.id = m.tournament_id
    where m.id = match_id and t.created_by = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.matches m
    join public.tournaments t on t.id = m.tournament_id
    where m.id = match_id and t.created_by = auth.uid()
  )
);

-- standings
create policy "standings are readable"
on public.standings
for select
using (exists (select 1 from public.tournaments t where t.id = tournament_id and t.deleted_at is null));

create policy "tournament creator manages standings"
on public.standings
for all
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- league_fixtures
create policy "league fixtures are readable"
on public.league_fixtures
for select
using (exists (select 1 from public.tournaments t where t.id = tournament_id and t.deleted_at is null));

create policy "tournament creator manages league fixtures"
on public.league_fixtures
for all
using (public.is_tournament_creator(tournament_id, auth.uid()))
with check (public.is_tournament_creator(tournament_id, auth.uid()));

-- match_events
create policy "match events are readable"
on public.match_events
for select
using (exists (
  select 1
  from public.matches m
  join public.tournaments t on t.id = m.tournament_id
  where m.id = match_id and t.deleted_at is null
));

create policy "tournament creator manages match events"
on public.match_events
for all
using (exists (
  select 1
  from public.matches m
  join public.tournaments t on t.id = m.tournament_id
  where m.id = match_id and t.created_by = auth.uid()
))
with check (exists (
  select 1
  from public.matches m
  join public.tournaments t on t.id = m.tournament_id
  where m.id = match_id and t.created_by = auth.uid()
));

-- subscription_plans
create policy "subscription plans are publicly readable"
on public.subscription_plans
for select
using (true);

-- user_subscriptions
create policy "users can view own subscriptions"
on public.user_subscriptions
for select
using (auth.uid() = user_id);

-- user_wallets
create policy "users can view own wallet"
on public.user_wallets
for select
using (auth.uid() = user_id);

-- transactions
create policy "users can view own transactions"
on public.transactions
for select
using (auth.uid() = user_id);

-- wallet_transaction_logs
create policy "users can view own wallet logs"
on public.wallet_transaction_logs
for select
using (exists (
  select 1 from public.user_wallets uw where uw.id = wallet_id and uw.user_id = auth.uid()
));

-- payment_attempts
create policy "users can view own payment attempts"
on public.payment_attempts
for select
using (auth.uid() = user_id);

-- notifications
create policy "users can view own notifications"
on public.notifications
for select
using (recipient_id = auth.uid() and deleted_at is null);

create policy "users can update own notifications"
on public.notifications
for update
using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());

-- notification_settings
create policy "users can view own notification settings"
on public.notification_settings
for select
using (user_id = auth.uid());

create policy "users can insert own notification settings"
on public.notification_settings
for insert
with check (user_id = auth.uid());

create policy "users can update own notification settings"
on public.notification_settings
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- user_devices
create policy "users can view own devices"
on public.user_devices
for select
using (user_id = auth.uid());

create policy "users can insert own devices"
on public.user_devices
for insert
with check (user_id = auth.uid());

create policy "users can update own devices"
on public.user_devices
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "users can delete own devices"
on public.user_devices
for delete
using (user_id = auth.uid());

-- =========================================================
-- 16) STORAGE POLICIES (OPTIONAL)
--    Assumes path conventions:
--    avatars/{user_id}/...
--    videos/{user_id}/...
--    thumbnails/{user_id}/...
--    challenge_videos/{user_id}/...
--    team_logos/{team_id}/...
-- Avatar policies: explicit text + LIKE (avoids 42P17 / 500 on uploads; see SupabaseAvatarStorage).
-- =========================================================
drop policy if exists "public read avatars" on storage.objects;
drop policy if exists "Public read avatars" on storage.objects;
drop policy if exists "users upload own avatars" on storage.objects;
drop policy if exists "Users insert own avatar folder" on storage.objects;
drop policy if exists "users update own avatars" on storage.objects;
drop policy if exists "Users update own avatar folder" on storage.objects;
drop policy if exists "Users delete own avatar folder" on storage.objects;
drop policy if exists "users delete own avatars" on storage.objects;
drop policy if exists "avatars_select_public" on storage.objects;
drop policy if exists "avatars_insert_own_folder" on storage.objects;
drop policy if exists "avatars_update_own_folder" on storage.objects;
drop policy if exists "avatars_delete_own_folder" on storage.objects;

create policy "avatars_select_public"
on storage.objects for select
to public
using ((bucket_id)::text = 'avatars');

create policy "avatars_insert_own_folder"
on storage.objects for insert
to authenticated
with check (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
);

create policy "avatars_update_own_folder"
on storage.objects for update
to authenticated
using (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
)
with check (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
);

create policy "avatars_delete_own_folder"
on storage.objects for delete
to authenticated
using (
  (bucket_id)::text = 'avatars'
  and auth.uid() is not null
  and (name)::text like (auth.uid()::text || '/%')
);

drop policy if exists "public read videos" on storage.objects;
drop policy if exists "users upload own videos and thumbnails" on storage.objects;

create policy "public read videos"
on storage.objects
for select
using (bucket_id in ('videos', 'thumbnails', 'challenge_videos', 'team_logos'));

create policy "users upload own videos and thumbnails"
on storage.objects
for insert
to authenticated
with check (
  (bucket_id in ('videos', 'thumbnails', 'challenge_videos') and auth.uid()::text = split_part(name, '/', 1))
  or (
    bucket_id = 'team_logos'
    and exists (
      select 1
      from public.teams t
      where t.id::text = split_part(name, '/', 1)
        and t.owner_id = auth.uid()
    )
  )
);

-- =========================================================
-- 17) AUTH TRIGGER (must come after dependent tables exist)
-- =========================================================
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- =========================================================
-- 18) PRIVILEGES FOR POSTGREST ROLES
-- =========================================================
grant usage on schema public to anon, authenticated, service_role;
grant select on all tables in schema public to anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant all privileges on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to anon, authenticated, service_role;
grant execute on all functions in schema public to anon, authenticated, service_role;

alter default privileges in schema public
  grant select on tables to anon;
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant all privileges on tables to service_role;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;

commit;
