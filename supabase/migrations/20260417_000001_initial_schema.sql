create extension if not exists pgcrypto;

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
  category_id uuid references public.video_categories(id) on delete set null,
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
  video_id uuid references public.videos(id) on delete set null,
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
create index videos_category_idx on public.videos (category_id, created_at desc);
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
