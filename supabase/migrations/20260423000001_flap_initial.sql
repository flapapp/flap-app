-- =============================================================================
-- FLAP: combined initial migration (schema, RLS, storage, RPC, seeds, grants)
-- Replaces per-step migrations for first Supabase deploy. Run once on a fresh project.
-- =============================================================================
create extension if not exists pgcrypto;

create extension if not exists pg_cron;

-- Video category: enum is the app-facing column; video_categories still holds labels for UI/seed.
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'video_category_enum'
      and n.nspname = 'public'
  ) then
    create type public.video_category_enum as enum (
      'goal',
      'shot_power',
      'pass',
      'long_pass',
      'dribble',
      'tackle',
      'penalty',
      'save',
      'wall',
      'strategy',
      'freestyle',
      'technique',
      'physics',
      'teamplay',
      'other'
    );
  end if;
end $$;


create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  display_name text not null,
  first_name text,
  last_name text,
  dat_of_birth date,
  nickname text,
  avatar_url text,
  city text,
  country text,
  position text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz
);

create table public.user_settings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  locale text not null default 'en' check (locale in ('en', 'ua')),
  notifications_enabled boolean not null default true,
  autoplay_videos boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'web')),
  device_id text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz,
  revoked_at timestamptz
);

create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.profiles(id) on delete cascade,
  to_user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  message text,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (from_user_id <> to_user_id)
);

create table public.friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_user_id uuid not null references public.profiles(id) on delete cascade,
  source_request_id uuid references public.friend_requests(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_id, friend_user_id),
  check (user_id <> friend_user_id)
);

create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  logo_url text,
  city text,
  is_public boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('captain', 'vice_captain', 'member')),
  joined_at timestamptz not null default now(),
  unique (team_id, user_id)
);

create table public.team_invites (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  invited_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create table public.team_join_requests (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  message text,
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  organizer_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  description text,
  scheduled_at timestamptz,
  location text,
  city text,
  latitude double precision,
  longitude double precision,
  max_players integer not null check (max_players > 0),
  participation_cost numeric(10,2) not null default 0,
  level text check (level in ('beginner', 'intermediate', 'advanced', 'pro')),
  auto_balance boolean not null default false,
  is_private boolean not null default false,
  is_team_match boolean not null default false,
  status text not null default 'open' check (status in ('open', 'full', 'in_progress', 'finished', 'cancelled')),
  started_at timestamptz,
  finished_at timestamptz,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.match_teams (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  team_slot integer not null check (team_slot > 0),
  source_team_id uuid references public.teams(id) on delete set null,
  display_name text,
  created_at timestamptz not null default now(),
  unique (match_id, team_slot)
);

create table public.match_participants (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_team_id uuid references public.match_teams(id) on delete set null,
  status text not null default 'pending_application' check (status in ('pending_application', 'accepted', 'rejected', 'left')),
  applied_at timestamptz not null default now(),
  responded_at timestamptz,
  joined_at timestamptz,
  unique (match_id, user_id)
);

create table public.match_invites (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  invited_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (match_id, user_id)
);

create table public.team_match_requests (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  requesting_team_id uuid not null references public.teams(id) on delete cascade,
  target_team_id uuid not null references public.teams(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create table public.team_match_request_players (
  team_match_request_id uuid not null references public.team_match_requests(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  primary key (team_match_request_id, player_id)
);

create table public.match_team_rosters (
  match_team_id uuid not null references public.match_teams(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'declined')),
  updated_at timestamptz not null default now(),
  primary key (match_team_id, player_id)
);

create table public.match_fixtures (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  home_match_team_id uuid not null references public.match_teams(id) on delete cascade,
  away_match_team_id uuid not null references public.match_teams(id) on delete cascade,
  status text not null default 'scheduled' check (status in ('scheduled', 'in_progress', 'finished', 'cancelled')),
  scheduled_at timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  home_score integer check (home_score >= 0),
  away_score integer check (away_score >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (home_match_team_id <> away_match_team_id)
);

create table public.match_player_goals (
  id uuid primary key default gen_random_uuid(),
  match_fixture_id uuid not null references public.match_fixtures(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  goals integer not null check (goals >= 0),
  unique (match_fixture_id, player_id)
);

create table public.rating_criteria (
  id uuid primary key default gen_random_uuid(),
  scope text not null check (scope in ('match', 'video', 'challenge_submission')),
  code text not null,
  label text not null,
  created_at timestamptz not null default now(),
  unique (scope, code)
);

create table public.match_player_ratings (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.profiles(id) on delete cascade,
  rated_by uuid not null references public.profiles(id) on delete cascade,
  overall_rating numeric(3,2) not null check (overall_rating >= 0 and overall_rating <= 10),
  rated_at timestamptz not null default now(),
  unique (match_id, player_id, rated_by)
);

create table public.match_player_rating_scores (
  match_player_rating_id uuid not null references public.match_player_ratings(id) on delete cascade,
  criterion_id uuid not null references public.rating_criteria(id) on delete restrict,
  score numeric(3,2) not null check (score >= 0 and score <= 10),
  primary key (match_player_rating_id, criterion_id)
);

create table public.video_categories (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  created_at timestamptz not null default now()
);

create table public.video_difficulties (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  created_at timestamptz not null default now()
);

create table public.videos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text,
  category public.video_category_enum not null default 'other'::public.video_category_enum,
  difficulty_id uuid references public.video_difficulties(id) on delete set null,
  video_url text not null,
  thumbnail_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.video_likes (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table public.video_comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  parent_comment_id uuid references public.video_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.video_views (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  viewer_user_id uuid references public.profiles(id) on delete set null,
  viewer_session_id text,
  created_at timestamptz not null default now()
);

create table public.video_ratings (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  rated_by uuid not null references public.profiles(id) on delete cascade,
  overall_rating numeric(3,2) not null check (overall_rating >= 0 and overall_rating <= 10),
  rated_at timestamptz not null default now(),
  unique (video_id, rated_by)
);

create table public.video_rating_scores (
  video_rating_id uuid not null references public.video_ratings(id) on delete cascade,
  criterion_id uuid not null references public.rating_criteria(id) on delete restrict,
  score numeric(3,2) not null check (score >= 0 and score <= 10),
  primary key (video_rating_id, criterion_id)
);

create table public.challenge_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  created_at timestamptz not null default now()
);

create table public.challenge_audiences (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  created_at timestamptz not null default now()
);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete restrict,
  title text not null,
  description text,
  challenge_type_id uuid references public.challenge_types(id) on delete set null,
  audience_id uuid references public.challenge_audiences(id) on delete set null,
  city text,
  entry_fee integer not null default 0 check (entry_fee >= 0),
  max_participants integer check (max_participants > 0),
  status text not null default 'recruiting' check (status in ('recruiting', 'submission', 'voting', 'completed', 'cancelled')),
  starts_at timestamptz,
  submission_deadline timestamptz,
  voting_deadline timestamptz,
  ends_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  image_url text,
  video_url text,
  video_thumbnail_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.challenge_tags (
  id uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table public.challenge_tag_links (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  tag_id uuid not null references public.challenge_tags(id) on delete cascade,
  primary key (challenge_id, tag_id)
);

create table public.challenge_participants (
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

create table public.challenge_submissions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text,
  description text,
  video_url text,
  thumbnail_url text,
  submitted_at timestamptz not null default now(),
  unique (challenge_id, user_id)
);

create table public.challenge_submission_ratings (
  id uuid primary key default gen_random_uuid(),
  challenge_submission_id uuid not null references public.challenge_submissions(id) on delete cascade,
  voter_user_id uuid not null references public.profiles(id) on delete cascade,
  overall_rating numeric(3,2) not null check (overall_rating >= 0 and overall_rating <= 10),
  created_at timestamptz not null default now(),
  unique (challenge_submission_id, voter_user_id)
);

create table public.challenge_submission_rating_scores (
  challenge_submission_rating_id uuid not null references public.challenge_submission_ratings(id) on delete cascade,
  criterion_id uuid not null references public.rating_criteria(id) on delete restrict,
  score numeric(3,2) not null check (score >= 0 and score <= 10),
  primary key (challenge_submission_rating_id, criterion_id)
);

create table public.challenge_prize_places (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  place integer not null check (place > 0),
  prize_amount numeric(12,2) not null check (prize_amount >= 0),
  winner_user_id uuid references public.profiles(id) on delete set null,
  unique (challenge_id, place)
);

create table public.challenge_completions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null unique references public.challenges(id) on delete cascade,
  completed_by uuid references public.profiles(id) on delete set null,
  completed_at timestamptz not null default now()
);

create table public.notification_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  notification_type_id uuid not null references public.notification_types(id) on delete restrict,
  title text not null,
  message text not null,
  related_table text,
  related_record_id uuid,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.push_notification_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  notification_type_id uuid references public.notification_types(id) on delete set null,
  related_table text,
  related_record_id uuid,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed', 'cancelled')),
  error_message text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  price_monthly integer not null default 0 check (price_monthly >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.features (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text
);

create table public.plan_features (
  plan_id uuid not null references public.subscription_plans(id) on delete cascade,
  feature_id uuid not null references public.features(id) on delete cascade,
  primary key (plan_id, feature_id)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  status text not null default 'active' check (status in ('trial', 'active', 'expired', 'cancelled')),
  auto_renew boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  trial_ends_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.badges (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  category text,
  emoji text,
  price integer not null default 0 check (price >= 0),
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  source text not null default 'purchase' check (source in ('purchase', 'award', 'auto_activity')),
  granted_at timestamptz not null default now(),
  granted_by uuid references public.profiles(id) on delete set null,
  primary key (user_id, badge_id)
);

create table public.transaction_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null
);

create table public.coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  transaction_type_id uuid not null references public.transaction_types(id) on delete restrict,
  amount integer not null,
  description text,
  created_at timestamptz not null default now()
);

create table public.coin_transaction_challenge_refs (
  coin_transaction_id uuid primary key references public.coin_transactions(id) on delete cascade,
  challenge_id uuid not null references public.challenges(id) on delete cascade
);

create table public.coin_transaction_submission_refs (
  coin_transaction_id uuid primary key references public.coin_transactions(id) on delete cascade,
  challenge_submission_id uuid not null references public.challenge_submissions(id) on delete cascade
);

create table public.coin_transaction_match_refs (
  coin_transaction_id uuid primary key references public.coin_transactions(id) on delete cascade,
  match_id uuid not null references public.matches(id) on delete cascade
);

create table public.coin_transaction_badge_refs (
  coin_transaction_id uuid primary key references public.coin_transactions(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade
);

create table public.coin_transaction_subscription_refs (
  coin_transaction_id uuid primary key references public.coin_transactions(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade
);

create table public.user_rating_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating_scope text not null check (rating_scope in ('overall', 'match', 'video')),
  rating_value numeric(4,2) not null,
  created_at timestamptz not null default now()
);

create index profiles_display_name_idx on public.profiles (display_name);
create index profiles_city_idx on public.profiles (city);
create index profiles_position_idx on public.profiles (position);

create index push_tokens_user_idx on public.push_tokens (user_id, revoked_at);

create unique index friend_requests_pending_pair_uq
  on public.friend_requests (least(from_user_id, to_user_id), greatest(from_user_id, to_user_id))
  where status = 'pending';
create index friend_requests_to_idx on public.friend_requests (to_user_id, status, created_at desc);
create index friend_requests_from_idx on public.friend_requests (from_user_id, status, created_at desc);
create index friendships_user_idx on public.friendships (user_id, created_at desc);

create unique index teams_name_lower_uq on public.teams (lower(name));
create index teams_created_by_idx on public.teams (created_by);
create index teams_city_idx on public.teams (city);
create index team_members_user_idx on public.team_members (user_id);
create unique index team_invites_pending_uq on public.team_invites (team_id, user_id) where status = 'pending';
create index team_invites_user_idx on public.team_invites (user_id, status, created_at desc);
create unique index team_join_requests_pending_uq on public.team_join_requests (team_id, user_id) where status = 'pending';
create index team_join_requests_team_idx on public.team_join_requests (team_id, status, created_at desc);

create index matches_organizer_idx on public.matches (organizer_id, created_at desc);
create index matches_status_scheduled_idx on public.matches (status, scheduled_at);
create index matches_city_scheduled_idx on public.matches (city, scheduled_at);
create index match_teams_match_idx on public.match_teams (match_id);
create index match_participants_match_idx on public.match_participants (match_id, status);
create index match_participants_user_idx on public.match_participants (user_id, status);
create index match_invites_user_idx on public.match_invites (user_id, status, created_at desc);
create index team_match_requests_match_idx on public.team_match_requests (match_id, status);
create index team_match_requests_requesting_idx on public.team_match_requests (requesting_team_id, status);
create index team_match_requests_target_idx on public.team_match_requests (target_team_id, status);
create index match_team_rosters_player_idx on public.match_team_rosters (player_id, status);
create index match_fixtures_match_idx on public.match_fixtures (match_id, status);
create index match_player_ratings_player_idx on public.match_player_ratings (player_id, rated_at desc);
create index match_player_ratings_match_idx on public.match_player_ratings (match_id);

create index videos_user_idx on public.videos (user_id, created_at desc);
create index videos_category_idx on public.videos (category, created_at desc);
create index videos_created_idx on public.videos (created_at desc);
create index video_comments_video_idx on public.video_comments (video_id, created_at desc);
create index video_views_video_idx on public.video_views (video_id, created_at desc);
create index video_ratings_video_idx on public.video_ratings (video_id, rated_at desc);

create index challenges_creator_idx on public.challenges (creator_id, created_at desc);
create index challenges_status_idx on public.challenges (status, starts_at, ends_at);
create index challenges_city_idx on public.challenges (city, status);
create index challenge_participants_user_idx on public.challenge_participants (user_id, joined_at desc);
create index challenge_submissions_challenge_idx on public.challenge_submissions (challenge_id, submitted_at desc);
create index challenge_submission_ratings_submission_idx on public.challenge_submission_ratings (challenge_submission_id, created_at desc);
create index challenge_prize_places_winner_idx on public.challenge_prize_places (winner_user_id);

create index notifications_user_idx on public.notifications (user_id, is_read, created_at desc);
create index notifications_type_idx on public.notifications (notification_type_id, created_at desc);
create index push_notification_queue_status_idx on public.push_notification_queue (status, created_at);
create index push_notification_queue_user_idx on public.push_notification_queue (user_id, created_at desc);

create unique index subscriptions_single_active_uq on public.subscriptions (user_id) where status in ('trial', 'active');
create index subscriptions_user_idx on public.subscriptions (user_id, starts_at desc);

create index user_badges_user_idx on public.user_badges (user_id, granted_at desc);

create index coin_transactions_user_idx on public.coin_transactions (user_id, created_at desc);
create index coin_transactions_type_idx on public.coin_transactions (transaction_type_id, created_at desc);

create index user_rating_snapshots_user_idx on public.user_rating_snapshots (user_id, rating_scope, created_at desc);

-- === prior file: 20260419_000002_rls_triggers_storage.sql ===
-- =============================================================================
-- RLS, helpers, triggers, storage (embedded in this migration)
-- Schema source: supabase/migrations/20260417_000001_initial_schema.sql
--
-- Assumptions (documented):
-- 1) Profiles are discoverable: authenticated users may SELECT all profiles for
--    search, matches, teams (typical social/sports app). Tighten with a
--    visibility column if you need private accounts.
-- 2) Cross-user notifications require a prior social/match/team/challenge link
--    via can_notify_user(). Badge endorsement to strangers may need an Edge
--    Function (service role) or adding sender_user_id + policy — see comments.
-- 3) coin_transactions INSERT is allowed for own user_id from the client (matches
--    current app). For production hardening, prefer SECURITY DEFINER RPCs that
--    validate amounts and types server-side.
-- 4) Service role bypasses RLS — use for admin scripts and Edge Functions.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SECTION A: Helper functions (SECURITY DEFINER, fixed search_path)
-- -----------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.is_admin from public.profiles p where p.id = (select auth.uid())),
    false
  );
$$;

create or replace function public.is_team_member(p_team_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = p_team_id
      and tm.user_id = p_user_id
  );
$$;

create or replace function public.is_team_officer(p_team_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = p_team_id
      and tm.user_id = p_user_id
      and tm.role in ('captain', 'vice_captain')
  );
$$;

create or replace function public.can_view_team(p_team_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.teams t
    where t.id = p_team_id
      and (
        t.is_public
        or t.created_by = p_viewer
        or public.is_team_member(p_team_id, p_viewer)
      )
  );
$$;

create or replace function public.can_view_match(p_match_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and (
        not m.is_private
        or m.organizer_id = p_viewer
        or exists (
          select 1 from public.match_participants mp
          where mp.match_id = m.id and mp.user_id = p_viewer
        )
        or exists (
          select 1 from public.match_invites mi
          where mi.match_id = m.id and mi.user_id = p_viewer
        )
      )
  );
$$;

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.friendships f
    where (f.user_id = a and f.friend_user_id = b)
       or (f.user_id = b and f.friend_user_id = a)
  );
$$;

-- Social / match / team / challenge overlap — used for notification INSERT
create or replace function public.can_notify_user(p_sender uuid, p_recipient uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_sender is not null
    and p_recipient is not null
    and p_sender <> p_recipient
    and (
      public.are_friends(p_sender, p_recipient)
      or exists (
        select 1
        from public.team_members tm1
        join public.team_members tm2
          on tm1.team_id = tm2.team_id
        where tm1.user_id = p_sender
          and tm2.user_id = p_recipient
      )
      or exists (
        select 1
        from public.match_participants mp1
        join public.match_participants mp2
          on mp1.match_id = mp2.match_id
        where mp1.user_id = p_sender
          and mp2.user_id = p_recipient
          and mp1.status = 'accepted'
          and mp2.status = 'accepted'
      )
      or exists (
        select 1
        from public.match_invites mi
        where mi.user_id = p_recipient
          and mi.invited_by = p_sender
      )
      or exists (
        select 1
        from public.match_invites mi
        where mi.user_id = p_sender
          and mi.invited_by = p_recipient
      )
      or exists (
        select 1
        from public.team_invites ti
        where ti.user_id = p_recipient
          and ti.invited_by = p_sender
      )
      or exists (
        select 1
        from public.challenges c
        join public.challenge_participants cp
          on cp.challenge_id = c.id
        where cp.user_id = p_recipient
          and c.creator_id = p_sender
      )
      or exists (
        select 1
        from public.challenges c
        join public.challenge_participants cp
          on cp.challenge_id = c.id
        where cp.user_id = p_sender
          and c.creator_id = p_recipient
      )
      or exists (
        select 1
        from public.matches m
        join public.match_participants mp
          on mp.match_id = m.id
        where m.organizer_id = p_sender
          and mp.user_id = p_recipient
      )
      or exists (
        select 1
        from public.matches m
        join public.match_participants mp
          on mp.match_id = m.id
        where m.organizer_id = p_recipient
          and mp.user_id = p_sender
      )
    );
$$;

comment on function public.can_notify_user(uuid, uuid) is
  'If badge endorsement or other cross-user events fail RLS, use Edge Function (service role) or add optional sender column + policy.';

-- -----------------------------------------------------------------------------
-- SECTION B: updated_at trigger
-- -----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Apply to tables that have updated_at (skip where trigger already exists)
do $$
declare
  r record;
begin
  for r in
    select unnest(array[
      'profiles',
      'user_settings',
      'teams',
      'matches',
      'videos',
      'video_comments',
      'match_fixtures',
      'challenges',
      'subscription_plans',
      'badges',
      'subscriptions'
    ]) as tbl
  loop
    execute format($f$
      drop trigger if exists trg_%I_updated_at on public.%I;
      create trigger trg_%I_updated_at
        before update on public.%I
        for each row
        execute function public.set_updated_at();
    $f$, r.tbl, r.tbl, r.tbl, r.tbl);
  end loop;
end;
$$;

-- match_team_rosters has updated_at but custom semantics — optional trigger
drop trigger if exists trg_match_team_rosters_updated_at on public.match_team_rosters;
create trigger trg_match_team_rosters_updated_at
  before update on public.match_team_rosters
  for each row
  execute function public.set_updated_at();

-- -----------------------------------------------------------------------------
-- SECTION C: Enable RLS on all public tables
-- -----------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.push_tokens enable row level security;
alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invites enable row level security;
alter table public.team_join_requests enable row level security;
alter table public.matches enable row level security;
alter table public.match_teams enable row level security;
alter table public.match_participants enable row level security;
alter table public.match_invites enable row level security;
alter table public.team_match_requests enable row level security;
alter table public.team_match_request_players enable row level security;
alter table public.match_team_rosters enable row level security;
alter table public.match_fixtures enable row level security;
alter table public.match_player_goals enable row level security;
alter table public.rating_criteria enable row level security;
alter table public.match_player_ratings enable row level security;
alter table public.match_player_rating_scores enable row level security;
alter table public.video_categories enable row level security;
alter table public.video_difficulties enable row level security;
alter table public.videos enable row level security;
alter table public.video_likes enable row level security;
alter table public.video_comments enable row level security;
alter table public.video_views enable row level security;
alter table public.video_ratings enable row level security;
alter table public.video_rating_scores enable row level security;
alter table public.challenge_types enable row level security;
alter table public.challenge_audiences enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_tags enable row level security;
alter table public.challenge_tag_links enable row level security;
alter table public.challenge_participants enable row level security;
alter table public.challenge_submissions enable row level security;
alter table public.challenge_submission_ratings enable row level security;
alter table public.challenge_submission_rating_scores enable row level security;
alter table public.challenge_prize_places enable row level security;
alter table public.challenge_completions enable row level security;
alter table public.notification_types enable row level security;
alter table public.notifications enable row level security;
alter table public.push_notification_queue enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.features enable row level security;
alter table public.plan_features enable row level security;
alter table public.subscriptions enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;
alter table public.transaction_types enable row level security;
alter table public.coin_transactions enable row level security;
alter table public.coin_transaction_challenge_refs enable row level security;
alter table public.coin_transaction_submission_refs enable row level security;
alter table public.coin_transaction_match_refs enable row level security;
alter table public.coin_transaction_badge_refs enable row level security;
alter table public.coin_transaction_subscription_refs enable row level security;
alter table public.user_rating_snapshots enable row level security;

-- -----------------------------------------------------------------------------
-- SECTION D: Policies — profiles & personal data
-- -----------------------------------------------------------------------------

create policy profiles_select_authenticated
  on public.profiles for select
  to authenticated
  using (true);

create policy profiles_insert_own
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy profiles_update_own_or_admin
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id or public.is_admin())
  with check ((select auth.uid()) = id or public.is_admin());

create policy profiles_delete_own_or_admin
  on public.profiles for delete
  to authenticated
  using ((select auth.uid()) = id or public.is_admin());

-- user_settings: own read/write; friends may read (profile screen loads another user's settings)
create policy user_settings_select_own_or_friend
  on public.user_settings for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or public.are_friends((select auth.uid()), user_id)
  );

create policy user_settings_insert_own
  on public.user_settings for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy user_settings_update_own
  on public.user_settings for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy user_settings_delete_own
  on public.user_settings for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- push_tokens
create policy push_tokens_select_own
  on public.push_tokens for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy push_tokens_insert_own
  on public.push_tokens for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy push_tokens_update_own
  on public.push_tokens for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy push_tokens_delete_own
  on public.push_tokens for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- -----------------------------------------------------------------------------
-- SECTION E: Friends
-- -----------------------------------------------------------------------------

create policy friend_requests_select_involved
  on public.friend_requests for select
  to authenticated
  using (
    (select auth.uid()) in (from_user_id, to_user_id)
  );

create policy friend_requests_insert_sender
  on public.friend_requests for insert
  to authenticated
  with check ((select auth.uid()) = from_user_id);

create policy friend_requests_update_involved
  on public.friend_requests for update
  to authenticated
  using ((select auth.uid()) in (from_user_id, to_user_id))
  with check ((select auth.uid()) in (from_user_id, to_user_id));

create policy friend_requests_delete_involved
  on public.friend_requests for delete
  to authenticated
  using ((select auth.uid()) in (from_user_id, to_user_id));

-- Friend graph is visible to any signed-in user (needed when loading another profile's
-- friend ids). Tighten to friends-only or private profiles if product requires it.
create policy friendships_select_authenticated
  on public.friendships for select
  to authenticated
  using (true);

create policy friendships_insert_participant
  on public.friendships for insert
  to authenticated
  with check ((select auth.uid()) in (user_id, friend_user_id));

create policy friendships_delete_involved
  on public.friendships for delete
  to authenticated
  using ((select auth.uid()) in (user_id, friend_user_id));

-- -----------------------------------------------------------------------------
-- SECTION F: Teams
-- -----------------------------------------------------------------------------

create policy teams_select_visible
  on public.teams for select
  to authenticated
  using (
    is_public
    or created_by = (select auth.uid())
    or public.is_team_member(id, (select auth.uid()))
  );

create policy teams_insert_creator
  on public.teams for insert
  to authenticated
  with check ((select auth.uid()) = created_by);

create policy teams_update_officer_or_creator
  on public.teams for update
  to authenticated
  using (
    public.is_admin()
    or created_by = (select auth.uid())
    or public.is_team_officer(id, (select auth.uid()))
  )
  with check (
    public.is_admin()
    or created_by = (select auth.uid())
    or public.is_team_officer(id, (select auth.uid()))
  );

create policy teams_delete_creator_or_admin
  on public.teams for delete
  to authenticated
  using (
    public.is_admin()
    or created_by = (select auth.uid())
  );

-- team_members
create policy team_members_select_if_team_visible
  on public.team_members for select
  to authenticated
  using (public.can_view_team(team_id, (select auth.uid())));

create policy team_members_insert_officer_or_self
  on public.team_members for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    or public.is_team_officer(team_id, (select auth.uid()))
  );

create policy team_members_update_officer_or_self
  on public.team_members for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    or public.is_team_officer(team_id, (select auth.uid()))
    or public.is_admin()
  )
  with check (
    (select auth.uid()) = user_id
    or public.is_team_officer(team_id, (select auth.uid()))
    or public.is_admin()
  );

create policy team_members_delete_officer_or_self
  on public.team_members for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or public.is_team_officer(team_id, (select auth.uid()))
    or public.is_admin()
  );

-- team_invites
create policy team_invites_select_involved
  on public.team_invites for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or public.is_team_officer(team_id, (select auth.uid()))
  );

create policy team_invites_insert_officer
  on public.team_invites for insert
  to authenticated
  with check (
    public.is_team_officer(team_id, (select auth.uid()))
    or public.is_admin()
  );

create policy team_invites_update_involved
  on public.team_invites for update
  to authenticated
  using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or public.is_team_officer(team_id, (select auth.uid()))
  )
  with check (true);

-- team_join_requests
create policy team_join_requests_select_involved
  on public.team_join_requests for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or public.is_team_officer(team_id, (select auth.uid()))
  );

create policy team_join_requests_insert_applicant
  on public.team_join_requests for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy team_join_requests_update_involved
  on public.team_join_requests for update
  to authenticated
  using (
    user_id = (select auth.uid())
    or public.is_team_officer(team_id, (select auth.uid()))
  )
  with check (true);

-- -----------------------------------------------------------------------------
-- SECTION G: Matches
-- -----------------------------------------------------------------------------

create policy matches_select_visible
  on public.matches for select
  to authenticated
  using (public.can_view_match(id, (select auth.uid())));

create policy matches_insert_organizer
  on public.matches for insert
  to authenticated
  with check ((select auth.uid()) = organizer_id);

create policy matches_update_organizer
  on public.matches for update
  to authenticated
  using ((select auth.uid()) = organizer_id or public.is_admin())
  with check ((select auth.uid()) = organizer_id or public.is_admin());

create policy matches_delete_organizer_or_admin
  on public.matches for delete
  to authenticated
  using ((select auth.uid()) = organizer_id or public.is_admin());

-- match_teams
create policy match_teams_select_if_match_visible
  on public.match_teams for select
  to authenticated
  using (public.can_view_match(match_id, (select auth.uid())));

create policy match_teams_mutate_organizer
  on public.match_teams for all
  to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.organizer_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.matches m
      where m.id = match_id
        and m.organizer_id = (select auth.uid())
    )
  );

-- match_participants
create policy match_participants_select_if_match_visible
  on public.match_participants for select
  to authenticated
  using (public.can_view_match(match_id, (select auth.uid())));

create policy match_participants_insert_self_apply
  on public.match_participants for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy match_participants_update_self_or_organizer
  on public.match_participants for update
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
  )
  with check (true);

create policy match_participants_delete_self_or_organizer
  on public.match_participants for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- match_invites
create policy match_invites_select_involved
  on public.match_invites for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
  );

create policy match_invites_insert_inviter_or_organizer
  on public.match_invites for insert
  to authenticated
  with check (
    invited_by = (select auth.uid())
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
  );

create policy match_invites_update_involved
  on public.match_invites for update
  to authenticated
  using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
  )
  with check (true);

-- team_match_requests
create policy team_match_requests_select_involved
  on public.team_match_requests for select
  to authenticated
  using (
    public.is_team_officer(requesting_team_id, (select auth.uid()))
    or public.is_team_officer(target_team_id, (select auth.uid()))
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
  );

create policy team_match_requests_insert_officer
  on public.team_match_requests for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and public.is_team_officer(requesting_team_id, (select auth.uid()))
  );

create policy team_match_requests_update_involved
  on public.team_match_requests for update
  to authenticated
  using (
    public.is_team_officer(requesting_team_id, (select auth.uid()))
    or public.is_team_officer(target_team_id, (select auth.uid()))
    or exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
  )
  with check (true);

-- team_match_request_players
create policy team_match_request_players_select_via_request
  on public.team_match_request_players for select
  to authenticated
  using (
    exists (
      select 1 from public.team_match_requests tmr
      where tmr.id = team_match_request_id
        and (
          public.is_team_officer(tmr.requesting_team_id, (select auth.uid()))
          or public.is_team_officer(tmr.target_team_id, (select auth.uid()))
          or exists (
            select 1 from public.matches m
            where m.id = tmr.match_id and m.organizer_id = (select auth.uid())
          )
        )
    )
    or player_id = (select auth.uid())
  );

create policy team_match_request_players_mutate_officer
  on public.team_match_request_players for all
  to authenticated
  using (
    exists (
      select 1 from public.team_match_requests tmr
      where tmr.id = team_match_request_id
        and public.is_team_officer(tmr.requesting_team_id, (select auth.uid()))
    )
  )
  with check (
    exists (
      select 1 from public.team_match_requests tmr
      where tmr.id = team_match_request_id
        and public.is_team_officer(tmr.requesting_team_id, (select auth.uid()))
    )
  );

-- match_team_rosters
create policy match_team_rosters_select_if_match_visible
  on public.match_team_rosters for select
  to authenticated
  using (
    exists (
      select 1 from public.match_teams mt
      join public.matches m on m.id = mt.match_id
      where mt.id = match_team_id
        and public.can_view_match(m.id, (select auth.uid()))
    )
  );

create policy match_team_rosters_mutate_player_or_organizer
  on public.match_team_rosters for all
  to authenticated
  using (
    player_id = (select auth.uid())
    or exists (
      select 1 from public.match_teams mt
      join public.matches m on m.id = mt.match_id
      where mt.id = match_team_id
        and m.organizer_id = (select auth.uid())
    )
  )
  with check (
    player_id = (select auth.uid())
    or exists (
      select 1 from public.match_teams mt
      join public.matches m on m.id = mt.match_id
      where mt.id = match_team_id
        and m.organizer_id = (select auth.uid())
    )
  );

-- match_fixtures
create policy match_fixtures_select_if_match_visible
  on public.match_fixtures for select
  to authenticated
  using (public.can_view_match(match_id, (select auth.uid())));

create policy match_fixtures_mutate_organizer
  on public.match_fixtures for all
  to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.matches m
      where m.id = match_id and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- match_player_goals
create policy match_player_goals_select_if_fixture_visible
  on public.match_player_goals for select
  to authenticated
  using (
    exists (
      select 1 from public.match_fixtures mf
      where mf.id = match_fixture_id
        and public.can_view_match(mf.match_id, (select auth.uid()))
    )
  );

create policy match_player_goals_mutate_organizer
  on public.match_player_goals for all
  to authenticated
  using (
    exists (
      select 1 from public.match_fixtures mf
      join public.matches m on m.id = mf.match_id
      where mf.id = match_fixture_id
        and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.match_fixtures mf
      join public.matches m on m.id = mf.match_id
      where mf.id = match_fixture_id
        and m.organizer_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- -----------------------------------------------------------------------------
-- SECTION H: Ratings (match)
-- -----------------------------------------------------------------------------

create policy rating_criteria_select_all
  on public.rating_criteria for select
  to authenticated
  using (true);

create policy rating_criteria_write_admin
  on public.rating_criteria for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy match_player_ratings_select_visible
  on public.match_player_ratings for select
  to authenticated
  using (
    rated_by = (select auth.uid())
    or player_id = (select auth.uid())
    or public.can_view_match(match_id, (select auth.uid()))
  );

create policy match_player_ratings_insert_rater
  on public.match_player_ratings for insert
  to authenticated
  with check (
    (select auth.uid()) = rated_by
    and rated_by <> player_id
    and public.can_view_match(match_id, (select auth.uid()))
  );

create policy match_player_ratings_update_own
  on public.match_player_ratings for update
  to authenticated
  using ((select auth.uid()) = rated_by)
  with check ((select auth.uid()) = rated_by);

create policy match_player_ratings_delete_own_or_admin
  on public.match_player_ratings for delete
  to authenticated
  using ((select auth.uid()) = rated_by or public.is_admin());

create policy match_player_rating_scores_all_via_parent
  on public.match_player_rating_scores for all
  to authenticated
  using (
    exists (
      select 1 from public.match_player_ratings r
      where r.id = match_player_rating_id
        and r.rated_by = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.match_player_ratings r
      where r.id = match_player_rating_id
        and r.rated_by = (select auth.uid())
    )
  );

-- -----------------------------------------------------------------------------
-- SECTION I: Videos
-- -----------------------------------------------------------------------------

create policy video_categories_select_all
  on public.video_categories for select
  to authenticated
  using (true);

create policy video_categories_write_admin
  on public.video_categories for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy video_difficulties_select_all
  on public.video_difficulties for select
  to authenticated
  using (true);

create policy video_difficulties_write_admin
  on public.video_difficulties for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy videos_select_authenticated
  on public.videos for select
  to authenticated
  using (true);

create policy videos_insert_owner
  on public.videos for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy videos_update_owner
  on public.videos for update
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin())
  with check ((select auth.uid()) = user_id or public.is_admin());

create policy videos_delete_owner
  on public.videos for delete
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin());

-- video_likes
create policy video_likes_select_all
  on public.video_likes for select
  to authenticated
  using (true);

create policy video_likes_insert_own
  on public.video_likes for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy video_likes_delete_own
  on public.video_likes for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- video_comments
create policy video_comments_select_all
  on public.video_comments for select
  to authenticated
  using (true);

create policy video_comments_insert_authenticated
  on public.video_comments for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy video_comments_update_own
  on public.video_comments for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy video_comments_delete_own_or_video_owner
  on public.video_comments for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.videos v
      where v.id = video_id and v.user_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- video_views (analytics — insert own or anonymous session)
create policy video_views_select_own_or_video_owner
  on public.video_views for select
  to authenticated
  using (
    viewer_user_id = (select auth.uid())
    or exists (
      select 1 from public.videos v
      where v.id = video_id and v.user_id = (select auth.uid())
    )
  );

create policy video_views_insert_authenticated
  on public.video_views for insert
  to authenticated
  with check (
    viewer_user_id is null
    or viewer_user_id = (select auth.uid())
  );

-- video_ratings
create policy video_ratings_select_all
  on public.video_ratings for select
  to authenticated
  using (true);

create policy video_ratings_insert_rater
  on public.video_ratings for insert
  to authenticated
  with check (
    (select auth.uid()) = rated_by
    and exists (
      select 1 from public.videos v
      where v.id = video_id and v.user_id <> (select auth.uid())
    )
  );

create policy video_ratings_update_own
  on public.video_ratings for update
  to authenticated
  using ((select auth.uid()) = rated_by)
  with check ((select auth.uid()) = rated_by);

create policy video_ratings_delete_own
  on public.video_ratings for delete
  to authenticated
  using ((select auth.uid()) = rated_by);

create policy video_rating_scores_all_via_parent
  on public.video_rating_scores for all
  to authenticated
  using (
    exists (
      select 1 from public.video_ratings vr
      where vr.id = video_rating_id
        and vr.rated_by = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.video_ratings vr
      where vr.id = video_rating_id
        and vr.rated_by = (select auth.uid())
    )
  );

-- -----------------------------------------------------------------------------
-- SECTION J: Challenges
-- -----------------------------------------------------------------------------

create policy challenge_types_select_all
  on public.challenge_types for select
  to authenticated
  using (true);

create policy challenge_types_write_admin
  on public.challenge_types for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy challenge_audiences_select_all
  on public.challenge_audiences for select
  to authenticated
  using (true);

create policy challenge_audiences_write_admin
  on public.challenge_audiences for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy challenges_select_authenticated
  on public.challenges for select
  to authenticated
  using (true);

create policy challenges_insert_creator
  on public.challenges for insert
  to authenticated
  with check ((select auth.uid()) = creator_id);

create policy challenges_update_creator_or_admin
  on public.challenges for update
  to authenticated
  using ((select auth.uid()) = creator_id or public.is_admin())
  with check ((select auth.uid()) = creator_id or public.is_admin());

create policy challenges_delete_creator_or_admin
  on public.challenges for delete
  to authenticated
  using ((select auth.uid()) = creator_id or public.is_admin());

-- challenge_tags
create policy challenge_tags_select_all
  on public.challenge_tags for select
  to authenticated
  using (true);

create policy challenge_tags_write_admin
  on public.challenge_tags for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- challenge_tag_links
create policy challenge_tag_links_select_all
  on public.challenge_tag_links for select
  to authenticated
  using (true);

create policy challenge_tag_links_write_creator
  on public.challenge_tag_links for all
  to authenticated
  using (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- challenge_participants
create policy challenge_participants_select_all
  on public.challenge_participants for select
  to authenticated
  using (true);

create policy challenge_participants_insert_self_or_creator
  on public.challenge_participants for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.creator_id = (select auth.uid())
    )
  );

create policy challenge_participants_delete_self_or_creator
  on public.challenge_participants for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- challenge_submissions
create policy challenge_submissions_select_all
  on public.challenge_submissions for select
  to authenticated
  using (true);

create policy challenge_submissions_insert_own
  on public.challenge_submissions for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy challenge_submissions_update_own
  on public.challenge_submissions for update
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin())
  with check ((select auth.uid()) = user_id or public.is_admin());

create policy challenge_submissions_delete_own_or_creator
  on public.challenge_submissions for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.challenges c
      where c.id = challenge_id and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- challenge_submission_ratings
create policy challenge_submission_ratings_select_all
  on public.challenge_submission_ratings for select
  to authenticated
  using (true);

create policy challenge_submission_ratings_insert_voter
  on public.challenge_submission_ratings for insert
  to authenticated
  with check (
    (select auth.uid()) = voter_user_id
    and exists (
      select 1 from public.challenge_submissions s
      where s.id = challenge_submission_id
        and s.user_id <> (select auth.uid())
    )
  );

create policy challenge_submission_ratings_update_own
  on public.challenge_submission_ratings for update
  to authenticated
  using ((select auth.uid()) = voter_user_id)
  with check ((select auth.uid()) = voter_user_id);

create policy challenge_submission_ratings_delete_own
  on public.challenge_submission_ratings for delete
  to authenticated
  using ((select auth.uid()) = voter_user_id);

create policy challenge_submission_rating_scores_all_via_parent
  on public.challenge_submission_rating_scores for all
  to authenticated
  using (
    exists (
      select 1 from public.challenge_submission_ratings r
      where r.id = challenge_submission_rating_id
        and r.voter_user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.challenge_submission_ratings r
      where r.id = challenge_submission_rating_id
        and r.voter_user_id = (select auth.uid())
    )
  );

-- challenge_prize_places
create policy challenge_prize_places_select_all
  on public.challenge_prize_places for select
  to authenticated
  using (true);

create policy challenge_prize_places_write_creator
  on public.challenge_prize_places for all
  to authenticated
  using (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- challenge_completions
create policy challenge_completions_select_all
  on public.challenge_completions for select
  to authenticated
  using (true);

create policy challenge_completions_write_creator
  on public.challenge_completions for all
  to authenticated
  using (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  )
  with check (
    exists (
      select 1 from public.challenges c
      where c.id = challenge_id
        and c.creator_id = (select auth.uid())
    )
    or public.is_admin()
  );

-- -----------------------------------------------------------------------------
-- SECTION K: Notifications
-- -----------------------------------------------------------------------------

create policy notification_types_select_all
  on public.notification_types for select
  to authenticated
  using (true);

create policy notification_types_write_admin
  on public.notification_types for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy notifications_select_own
  on public.notifications for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy notifications_insert_self_or_allowed
  on public.notifications for insert
  to authenticated
  with check (
    public.is_admin()
    or (select auth.uid()) = user_id
    or public.can_notify_user((select auth.uid())::uuid, user_id)
  );

create policy notifications_update_own
  on public.notifications for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy notifications_delete_own
  on public.notifications for delete
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin());

-- push_notification_queue — same insert rules; workers use service role
create policy push_queue_select_own
  on public.push_notification_queue for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy push_queue_insert_self_or_allowed
  on public.push_notification_queue for insert
  to authenticated
  with check (
    public.is_admin()
    or (select auth.uid()) = user_id
    or public.can_notify_user((select auth.uid())::uuid, user_id)
  );

create policy push_queue_update_own
  on public.push_notification_queue for update
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin())
  with check ((select auth.uid()) = user_id or public.is_admin());

create policy push_queue_delete_own_or_admin
  on public.push_notification_queue for delete
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin());

-- -----------------------------------------------------------------------------
-- SECTION L: Subscriptions & catalog
-- -----------------------------------------------------------------------------

create policy subscription_plans_select_all
  on public.subscription_plans for select
  to authenticated
  using (true);

create policy subscription_plans_write_admin
  on public.subscription_plans for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy features_select_all
  on public.features for select
  to authenticated
  using (true);

create policy features_write_admin
  on public.features for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy plan_features_select_all
  on public.plan_features for select
  to authenticated
  using (true);

create policy plan_features_write_admin
  on public.plan_features for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Subscription tier is shown on public profile documents
create policy subscriptions_select_authenticated
  on public.subscriptions for select
  to authenticated
  using (true);

create policy subscriptions_insert_own
  on public.subscriptions for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy subscriptions_update_own
  on public.subscriptions for update
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin())
  with check ((select auth.uid()) = user_id or public.is_admin());

create policy subscriptions_delete_own_or_admin
  on public.subscriptions for delete
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin());

-- -----------------------------------------------------------------------------
-- SECTION M: Badges & coins
-- -----------------------------------------------------------------------------

create policy badges_select_all
  on public.badges for select
  to authenticated
  using (true);

create policy badges_write_admin
  on public.badges for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Badges are treated as public on profiles (store / endorsements UI)
create policy user_badges_select_authenticated
  on public.user_badges for select
  to authenticated
  using (true);

create policy user_badges_insert_own_or_admin
  on public.user_badges for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    or (select auth.uid()) = granted_by
    or public.is_admin()
  );

create policy user_badges_delete_own_or_admin
  on public.user_badges for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or public.is_admin()
  );

create policy transaction_types_select_all
  on public.transaction_types for select
  to authenticated
  using (true);

create policy transaction_types_write_admin
  on public.transaction_types for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Balance on others' profiles: friends see ledger; strangers get no rows (sum 0 in app)
create policy coin_transactions_select_own_or_friend
  on public.coin_transactions for select
  to authenticated
  using (
    public.is_admin()
    or (select auth.uid()) = user_id
    or public.are_friends((select auth.uid()), user_id)
  );

create policy coin_transactions_insert_own
  on public.coin_transactions for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- Ref tables: same owner as parent transaction
create policy coin_ref_challenge_select_own
  on public.coin_transaction_challenge_refs for select
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_challenge_mutate_own
  on public.coin_transaction_challenge_refs for all
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_submission_select_own
  on public.coin_transaction_submission_refs for select
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_submission_mutate_own
  on public.coin_transaction_submission_refs for all
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_match_select_own
  on public.coin_transaction_match_refs for select
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_match_mutate_own
  on public.coin_transaction_match_refs for all
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_badge_select_own
  on public.coin_transaction_badge_refs for select
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_badge_mutate_own
  on public.coin_transaction_badge_refs for all
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_subscription_select_own
  on public.coin_transaction_subscription_refs for select
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

create policy coin_ref_subscription_mutate_own
  on public.coin_transaction_subscription_refs for all
  to authenticated
  using (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.coin_transactions t
      where t.id = coin_transaction_id
        and t.user_id = (select auth.uid())
    )
  );

-- -----------------------------------------------------------------------------
-- SECTION N: User rating snapshots
-- -----------------------------------------------------------------------------

create policy user_rating_snapshots_select_authenticated
  on public.user_rating_snapshots for select
  to authenticated
  using (true);

create policy user_rating_snapshots_insert_own
  on public.user_rating_snapshots for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy user_rating_snapshots_delete_own_or_admin
  on public.user_rating_snapshots for delete
  to authenticated
  using ((select auth.uid()) = user_id or public.is_admin());

-- -----------------------------------------------------------------------------
-- SECTION O: Extra indexes (FK / filter helpers)
-- -----------------------------------------------------------------------------

create index if not exists match_invites_match_user_idx
  on public.match_invites (match_id, user_id);

create index if not exists team_invites_team_user_idx
  on public.team_invites (team_id, user_id);

create index if not exists video_views_video_created_idx
  on public.video_views (video_id, created_at desc);

-- -----------------------------------------------------------------------------
-- SECTION P: Storage (run in SQL editor or separate migration after creating buckets)
-- -----------------------------------------------------------------------------
--
-- Create buckets in Dashboard: Storage → New bucket
--   - avatars        (public: optional — public read simplifies profile images)
--   - team-logos
--   - videos
--   - challenge-images
--
-- Example policies for storage.objects (adjust bucket names):
--
-- create policy "Avatar images are publicly readable"
--   on storage.objects for select
--   to authenticated, anon
--   using (bucket_id = 'avatars');
--
-- create policy "Users upload own avatar"
--   on storage.objects for insert
--   to authenticated
--   with check (
--     bucket_id = 'avatars'
--     and (storage.foldername(name))[1] = (select auth.uid()::text)
--   );
--
-- create policy "Users update own avatar"
--   on storage.objects for update
--   to authenticated
--   using (
--     bucket_id = 'avatars'
--     and (storage.foldername(name))[1] = (select auth.uid()::text)
--   );
--
-- create policy "Users delete own avatar"
--   on storage.objects for delete
--   to authenticated
--   using (
--     bucket_id = 'avatars'
--     and (storage.foldername(name))[1] = (select auth.uid()::text)
--   );
--
-- Private bucket example (videos): only owner can read/write under their folder:
--
-- create policy "Video owner read"
--   on storage.objects for select
--   to authenticated
--   using (
--     bucket_id = 'videos'
--     and (storage.foldername(name))[1] = (select auth.uid()::text)
--   );
--

-- -----------------------------------------------------------------------------
-- Grants: ensure app roles can use helpers (execute already default for public schema in Supabase)
-- -----------------------------------------------------------------------------

grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_team_member(uuid, uuid) to authenticated;
grant execute on function public.is_team_officer(uuid, uuid) to authenticated;
grant execute on function public.can_view_team(uuid, uuid) to authenticated;
grant execute on function public.can_view_match(uuid, uuid) to authenticated;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.can_notify_user(uuid, uuid) to authenticated;

-- === prior file: 20260421_000003_storage_buckets.sql ===
-- =============================================================================
-- Supabase Storage: buckets + object policies (public read, user-scoped writes)
-- Aligns with lib/core/supabase/supabase_app_storage.dart bucket ids.
-- =============================================================================

-- Public buckets for app media (URLs stored in Firestore / Supabase rows)
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('videos', 'videos', true),
  ('team-logos', 'team-logos', true),
  ('thumbnails', 'thumbnails', true),
  ('challenge-thumbnails', 'challenge-thumbnails', true),
  ('submission-thumbnails', 'submission-thumbnails', true),
  ('match-covers', 'match-covers', true)
on conflict (id) do update
set public = excluded.public;

-- Helper: first path segment must equal auth.uid() (user-owned prefix)
-- Policies are split per bucket so MIME limits can be added later per bucket.

-- avatars
drop policy if exists "storage_avatars_select" on storage.objects;
create policy "storage_avatars_select"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "storage_avatars_insert" on storage.objects;
create policy "storage_avatars_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_avatars_update" on storage.objects;
create policy "storage_avatars_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_avatars_delete" on storage.objects;
create policy "storage_avatars_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- videos
drop policy if exists "storage_videos_select" on storage.objects;
create policy "storage_videos_select"
  on storage.objects for select
  to public
  using (bucket_id = 'videos');

drop policy if exists "storage_videos_insert" on storage.objects;
create policy "storage_videos_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_videos_update" on storage.objects;
create policy "storage_videos_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_videos_delete" on storage.objects;
create policy "storage_videos_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'videos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- team-logos
drop policy if exists "storage_team_logos_select" on storage.objects;
create policy "storage_team_logos_select"
  on storage.objects for select
  to public
  using (bucket_id = 'team-logos');

drop policy if exists "storage_team_logos_insert" on storage.objects;
create policy "storage_team_logos_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_team_logos_update" on storage.objects;
create policy "storage_team_logos_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_team_logos_delete" on storage.objects;
create policy "storage_team_logos_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'team-logos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- thumbnails (video)
drop policy if exists "storage_thumbnails_select" on storage.objects;
create policy "storage_thumbnails_select"
  on storage.objects for select
  to public
  using (bucket_id = 'thumbnails');

drop policy if exists "storage_thumbnails_insert" on storage.objects;
create policy "storage_thumbnails_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_thumbnails_update" on storage.objects;
create policy "storage_thumbnails_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_thumbnails_delete" on storage.objects;
create policy "storage_thumbnails_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- challenge-thumbnails
drop policy if exists "storage_challenge_thumbnails_select" on storage.objects;
create policy "storage_challenge_thumbnails_select"
  on storage.objects for select
  to public
  using (bucket_id = 'challenge-thumbnails');

drop policy if exists "storage_challenge_thumbnails_insert" on storage.objects;
create policy "storage_challenge_thumbnails_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_challenge_thumbnails_update" on storage.objects;
create policy "storage_challenge_thumbnails_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_challenge_thumbnails_delete" on storage.objects;
create policy "storage_challenge_thumbnails_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'challenge-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- submission-thumbnails (path: {uid}/{challengeId}/file)
drop policy if exists "storage_submission_thumbnails_select" on storage.objects;
create policy "storage_submission_thumbnails_select"
  on storage.objects for select
  to public
  using (bucket_id = 'submission-thumbnails');

drop policy if exists "storage_submission_thumbnails_insert" on storage.objects;
create policy "storage_submission_thumbnails_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_submission_thumbnails_update" on storage.objects;
create policy "storage_submission_thumbnails_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_submission_thumbnails_delete" on storage.objects;
create policy "storage_submission_thumbnails_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'submission-thumbnails'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- match-covers (path: {uid}/{matchId}/file)
drop policy if exists "storage_match_covers_select" on storage.objects;
create policy "storage_match_covers_select"
  on storage.objects for select
  to public
  using (bucket_id = 'match-covers');

drop policy if exists "storage_match_covers_insert" on storage.objects;
create policy "storage_match_covers_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_match_covers_update" on storage.objects;
create policy "storage_match_covers_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_match_covers_delete" on storage.objects;
create policy "storage_match_covers_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'match-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- === prior file: 20260422_000005_edge_functions_rpc_cron_replacements.sql ===
-- Replace Firebase Cloud Functions with Postgres-native RPC + cron helpers.
-- Push delivery is intentionally disabled in this migration window; queue rows
-- are marked as sent/cancelled by Edge worker without external dispatch.

create extension if not exists pg_cron;

create or replace function public.ensure_notification_type(p_code text, p_label text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id
  from public.notification_types
  where code = p_code
  limit 1;

  if v_id is null then
    insert into public.notification_types(code, label)
    values (p_code, p_label)
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

create or replace function public.accept_friend_request_rpc(
  p_request_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req public.friend_requests%rowtype;
  v_type_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.friend_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Friend request not found';
  end if;
  if v_req.to_user_id <> v_uid then
    raise exception 'Not your friend request';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'Friend request already processed';
  end if;

  update public.friend_requests
  set status = case when p_accept then 'accepted' else 'declined' end,
      responded_at = now()
  where id = v_req.id;

  if p_accept then
    insert into public.friendships(user_id, friend_user_id, source_request_id)
    values
      (v_req.from_user_id, v_req.to_user_id, v_req.id),
      (v_req.to_user_id, v_req.from_user_id, v_req.id)
    on conflict (user_id, friend_user_id) do nothing;

    v_type_id := public.ensure_notification_type(
      'friend_request_accepted',
      'Friend request accepted'
    );

    insert into public.notifications(
      user_id, notification_type_id, title, message, related_table, related_record_id
    )
    values (
      v_req.from_user_id,
      v_type_id,
      'Friend request accepted',
      'Your friend request was accepted.',
      'friend_requests',
      v_req.id
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'status', case when p_accept then 'accepted' else 'declined' end
  );
end;
$$;

create or replace function public.advance_challenge_statuses_rpc()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  update public.challenges
  set status = case
      when status = 'recruiting' and submission_deadline is not null and now() >= submission_deadline then 'submission'
      when status = 'submission' and voting_deadline is not null and now() >= voting_deadline then 'voting'
      when status = 'voting' and ends_at is not null and now() >= ends_at then 'completed'
      else status
    end,
    updated_at = now()
  where status in ('recruiting', 'submission', 'voting');

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.cleanup_old_notifications_rpc(p_days integer default 30)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  delete from public.notifications
  where created_at <= now() - make_interval(days => p_days);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname in (
    'flap_advance_challenge_statuses',
    'flap_cleanup_old_notifications'
  );
exception
  when undefined_table then
    null;
end $$;

select cron.schedule(
  'flap_advance_challenge_statuses',
  '0 * * * *',
  $$select public.advance_challenge_statuses_rpc();$$
);

select cron.schedule(
  'flap_cleanup_old_notifications',
  '15 3 * * *',
  $$select public.cleanup_old_notifications_rpc(30);$$
);

-- === prior file: 20260422_000006_seed_lookup_defaults.sql ===
-- Seed essential lookup/reference rows required by client bootstrap.
-- Keep this idempotent for local/dev resets and repeated deploys.

insert into public.subscription_plans (code, name, price_monthly, is_active)
values
  ('free', 'Free', 0, true),
  ('europa', 'Europa League', 49, true),
  ('champions', 'Champions League', 89, true),
  ('champions_league', 'Champions League', 89, true)
on conflict (code) do update
set
  name = excluded.name,
  price_monthly = excluded.price_monthly,
  is_active = excluded.is_active,
  updated_at = now();

insert into public.transaction_types (code, label)
values
  ('badge_awarded', 'Badge awarded'),
  ('badge_purchase', 'Badge purchase'),
  ('challenge_create_fee', 'Challenge creation fee'),
  ('challenge_entry_fee', 'Challenge entry fee'),
  ('challenge_prize', 'Challenge prize'),
  ('challenge_refund', 'Challenge refund'),
  ('challenge_submission', 'Challenge submission'),
  ('challenge_voting_complete', 'Challenge voting complete'),
  ('friend_added', 'Friend added'),
  ('friend_request_sent', 'Friend request sent'),
  ('signup_bonus', 'Signup bonus'),
  ('subscription_bonus', 'Subscription bonus'),
  ('voting_reward', 'Voting reward')
on conflict (code) do update
set label = excluded.label;

insert into public.badges (code, name, description, category, emoji, price, is_available)
values
  ('rookie', 'Rookie', 'First step into FLAP world', 'starter', '🌟', 50, true),
  ('first_goal', 'First Goal', 'Scored your first goal!', 'starter', '⚽', 30, true),
  ('striker', 'Striker', 'Master of goal moments', 'skill', '🔥', 40, true),
  ('defender', 'Defender', 'Reliable as a rock', 'skill', '🛡️', 33, true),
  ('playmaker', 'Playmaker', 'Master of assists and passes', 'skill', '🎯', 47, true),
  ('goalkeeper', 'Goalkeeper', 'Invincible gatekeeper', 'skill', '🥅', 37, true),
  ('speedster', 'Speedster', 'Fast as lightning', 'skill', '⚡', 30, true),
  ('trickster', 'Trickster', 'Master of technical skills', 'achievement', '🎪', 130, true),
  ('social', 'Social', 'Soul of team and community', 'special', '👥', 80, true),
  ('challenger', 'Challenger', 'Winner of 10+ challenges', 'achievement', '🎖️', 180, true),
  ('perfectionist', 'Perfectionist', 'Average video rating 4.5+', 'achievement', '💎', 200, true),
  ('veteran', 'Veteran', 'Experienced FLAP player', 'legendary', '⭐', 250, true),
  ('legend', 'Legend', 'Legend of football world', 'legendary', '👑', 300, true),
  ('champion', 'Champion', 'Best of the best', 'legendary', '🏆', 400, true),
  ('hall_of_fame', 'Hall of Fame', 'Entered FLAP Hall of Fame', 'legendary', '🌟', 500, true)
on conflict (code) do update
set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  emoji = excluded.emoji,
  price = excluded.price,
  is_available = excluded.is_available,
  updated_at = now();

-- === prior file: 20260422_000007_seed_video_lookups.sql ===
insert into public.video_categories (code, label)
values
  ('goal', 'Goal'),
  ('shot_power', 'Shot power'),
  ('pass', 'Pass'),
  ('long_pass', 'Long pass'),
  ('dribble', 'Dribbling'),
  ('tackle', 'Tackle'),
  ('penalty', 'Penalty'),
  ('save', 'Save'),
  ('wall', 'Wall / set-piece'),
  ('strategy', 'Strategy'),
  ('freestyle', 'Freestyle'),
  ('technique', 'Technique (legacy)'),
  ('physics', 'Physics (legacy)'),
  ('teamplay', 'Teamplay (legacy)'),
  ('other', 'Other')
on conflict (code) do nothing;

insert into public.video_difficulties (code, label)
values
  ('easy', 'Easy'),
  ('medium', 'Medium'),
  ('hard', 'Hard'),
  ('pro', 'Pro')
on conflict (code) do nothing;

-- === prior file: 20260422_000004_public_schema_usage_for_api_roles.sql ===
-- PostgREST connects as roles `anon` / `authenticated` (JWT) / `service_role`.
-- Without USAGE on schema public, the API returns:
--   PostgrestException: permission denied for schema public (42501)
-- This can appear after a partial restore, manual role changes, or non-standard DB setup.
-- Runtime can also fail with table-level permissions like:
--   PostgrestException: permission denied for table profiles (42501)
-- Safe to re-run (idempotent grants).

grant usage on schema public to anon, authenticated, service_role;

-- Let API roles access existing objects in public.
-- RLS policies still control row-level access.
grant select, insert, update, delete on all tables in schema public
  to anon, authenticated, service_role;
grant usage, select on all sequences in schema public
  to anon, authenticated, service_role;
grant execute on all functions in schema public
  to anon, authenticated, service_role;

-- Ensure future objects in public receive the same privileges.
alter default privileges in schema public
  grant select, insert, update, delete on tables
  to anon, authenticated, service_role;
alter default privileges in schema public
  grant usage, select on sequences
  to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions
  to anon, authenticated, service_role;

-- Enums: USAGE is required for PostgREST/typed columns (no "ALL TYPES IN SCHEMA" in PostgreSQL).
grant usage on type public.video_category_enum to anon, authenticated, service_role;
