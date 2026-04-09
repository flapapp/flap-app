-- Full challenges + submissions on Supabase (replaces Firestore challenges / subcollections).
-- Coins + wallet use existing public.profiles.coins and public.wallet_transactions.

alter table public.profiles
  add column if not exists country text;

-- Extend challenges (minimal stub from admin migration).
alter table public.challenges
  add column if not exists title text not null default '',
  add column if not exists description text not null default '',
  add column if not exists type text not null default 'other',
  add column if not exists audience text not null default 'city',
  add column if not exists creator_id uuid references public.profiles (id) on delete cascade,
  add column if not exists creator_name text not null default '',
  add column if not exists creator_video_url text,
  add column if not exists creator_thumbnail_url text,
  add column if not exists city text not null default '',
  add column if not exists entry_fee integer not null default 10,
  add column if not exists duration integer not null default 7,
  add column if not exists start_date timestamptz,
  add column if not exists submission_deadline timestamptz,
  add column if not exists voting_deadline timestamptz,
  add column if not exists end_date timestamptz,
  add column if not exists status text not null default 'recruiting',
  add column if not exists max_participants integer not null default 50,
  add column if not exists current_participants integer not null default 0,
  add column if not exists prize_pool double precision not null default 0,
  add column if not exists participants uuid[] not null default '{}',
  add column if not exists submission_user_ids uuid[] not null default '{}',
  add column if not exists votes jsonb not null default '{}'::jsonb,
  add column if not exists detailed_votes jsonb not null default '{}'::jsonb,
  add column if not exists winners uuid[] not null default '{}',
  add column if not exists final_scores jsonb not null default '{}'::jsonb,
  add column if not exists winner_prizes jsonb not null default '{}'::jsonb,
  add column if not exists is_active boolean not null default true,
  add column if not exists image_url text,
  add column if not exists tags text[] not null default '{}',
  add column if not exists completed_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- Submissions: one row per (challenge, user) — mirrors Firestore doc id = userId.
alter table public.submissions
  add column if not exists user_id uuid references public.profiles (id) on delete cascade,
  add column if not exists video_id text,
  add column if not exists video_url text not null default '',
  add column if not exists title text not null default '',
  add column if not exists author_name text not null default '',
  add column if not exists average_rating double precision not null default 0,
  add column if not exists vote_count integer not null default 0,
  add column if not exists votes jsonb not null default '{}'::jsonb,
  add column if not exists thumbnail_url text,
  add column if not exists is_creator_video boolean not null default false,
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

delete from public.submissions where user_id is null or challenge_id is null;

alter table public.submissions
  drop constraint if exists submissions_challenge_user_key;

alter table public.submissions
  add constraint submissions_challenge_user_key unique (challenge_id, user_id);

create index if not exists submissions_challenge_id_idx
  on public.submissions (challenge_id, average_rating desc);

-- Votes: one row per (challenge, voter, submission author).
create table if not exists public.challenge_votes (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  submission_user_id uuid not null,
  rating double precision not null,
  created_at timestamptz not null default now(),
  unique (challenge_id, voter_id, submission_user_id)
);

create index if not exists challenge_votes_challenge_idx
  on public.challenge_votes (challenge_id);

-- Optional friend graph for invitation targeting (populate separately).
create table if not exists public.user_friends (
  user_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  constraint user_friends_no_self check (user_id <> friend_id)
);

create table if not exists public.challenge_celebration_ack (
  user_id uuid not null references public.profiles (id) on delete cascade,
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  shown_at timestamptz not null default now(),
  primary key (user_id, challenge_id)
);

alter table public.challenge_votes enable row level security;
alter table public.user_friends enable row level security;
alter table public.challenge_celebration_ack enable row level security;

-- Select policies (mutations via RPC / security definer).
drop policy if exists "challenges_select_authenticated" on public.challenges;
create policy "challenges_select_authenticated"
  on public.challenges for select
  to authenticated
  using (true);

drop policy if exists "submissions_select_authenticated" on public.submissions;
create policy "submissions_select_authenticated"
  on public.submissions for select
  to authenticated
  using (true);

drop policy if exists "challenge_votes_select_authenticated" on public.challenge_votes;
create policy "challenge_votes_select_authenticated"
  on public.challenge_votes for select
  to authenticated
  using (true);

drop policy if exists "user_friends_select_own" on public.user_friends;
create policy "user_friends_select_own"
  on public.user_friends for select
  to authenticated
  using (auth.uid() = user_id or auth.uid() = friend_id);

drop policy if exists "celebration_ack_select_own" on public.challenge_celebration_ack;
create policy "celebration_ack_select_own"
  on public.challenge_celebration_ack for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "celebration_ack_insert_own" on public.challenge_celebration_ack;
create policy "celebration_ack_insert_own"
  on public.challenge_celebration_ack for insert
  to authenticated
  with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- RPC: create challenge (deduct entry fee, seed prize pool = entry fee)
-- ---------------------------------------------------------------------------
create or replace function public.create_challenge(
  p_title text,
  p_description text,
  p_type text,
  p_audience text,
  p_creator_name text,
  p_city text,
  p_entry_fee integer,
  p_duration integer,
  p_start_date timestamptz,
  p_submission_deadline timestamptz,
  p_voting_deadline timestamptz,
  p_end_date timestamptz,
  p_max_participants integer,
  p_status text,
  p_tags text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_coins int;
  v_sub_active boolean;
  v_max_per_month int;
  v_recent int;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select coins, coalesce(subscription_active, false), coalesce(max_challenges_per_month, 1)
    into v_coins, v_sub_active, v_max_per_month
  from public.profiles
  where id = v_uid
  for update;

  if not found then
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;

  if v_coins < p_entry_fee then
    raise exception 'insufficient_coins' using errcode = 'P0001';
  end if;

  if not v_sub_active then
    select count(*)::int into v_recent
    from public.challenges
    where creator_id = v_uid
      and created_at >= (now() - interval '30 days');

    if v_recent >= v_max_per_month then
      raise exception 'challenge_monthly_limit' using errcode = 'P0001';
    end if;
  end if;

  update public.profiles
  set coins = coins - p_entry_fee,
      updated_at = now()
  where id = v_uid;

  insert into public.wallet_transactions (user_id, type, amount, description)
  values (
    v_uid,
    'challenge_create_fee',
    -p_entry_fee,
    concat('Challenge creation fee: ', left(p_title, 120))
  );

  insert into public.challenges (
    title, description, type, audience, creator_id, creator_name, city,
    entry_fee, duration, start_date, submission_deadline, voting_deadline, end_date,
    status, max_participants, current_participants, prize_pool, tags
  ) values (
    coalesce(p_title, ''),
    coalesce(p_description, ''),
    coalesce(p_type, 'other'),
    coalesce(p_audience, 'city'),
    v_uid,
    coalesce(p_creator_name, ''),
    coalesce(p_city, ''),
    p_entry_fee,
    p_duration,
    p_start_date,
    p_submission_deadline,
    p_voting_deadline,
    p_end_date,
    coalesce(p_status, 'recruiting'),
    coalesce(p_max_participants, 50),
    0,
    p_entry_fee::double precision,
    coalesce(p_tags, '{}')
  )
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.create_challenge(
  text, text, text, text, text, text, int, int,
  timestamptz, timestamptz, timestamptz, timestamptz,
  int, text, text[]
) to authenticated;

-- ---------------------------------------------------------------------------
-- Add creator as participant without charging entry fee
-- ---------------------------------------------------------------------------
create or replace function public.challenge_add_creator_participant(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  update public.challenges c
  set
    participants = case
      when v_uid = any (c.participants) then c.participants
      else array_append(c.participants, v_uid)
    end,
    current_participants = c.current_participants + case
      when v_uid = any (c.participants) then 0 else 1
    end,
    updated_at = now()
  where c.id = p_challenge_id
    and c.creator_id = v_uid;

  if not found then
    raise exception 'challenge_not_found_or_forbidden' using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.challenge_add_creator_participant(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Join challenge (pay entry fee)
-- ---------------------------------------------------------------------------
create or replace function public.join_challenge(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_coins int;
  r public.challenges%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into r from public.challenges where id = p_challenge_id for update;
  if not found then
    raise exception 'challenge_not_found' using errcode = 'P0001';
  end if;

  if not r.is_active then
    raise exception 'challenge_inactive' using errcode = 'P0001';
  end if;

  if r.current_participants >= r.max_participants then
    raise exception 'challenge_full' using errcode = 'P0001';
  end if;

  if v_uid = any (r.participants) then
    raise exception 'already_joined' using errcode = 'P0001';
  end if;

  if r.status not in ('recruiting', 'submission') then
    raise exception 'cannot_join_status' using errcode = 'P0001';
  end if;

  select coins into v_coins from public.profiles where id = v_uid for update;
  if v_coins < r.entry_fee then
    raise exception 'insufficient_coins' using errcode = 'P0001';
  end if;

  update public.profiles set coins = coins - r.entry_fee, updated_at = now() where id = v_uid;

  update public.challenges
  set
    participants = array_append(participants, v_uid),
    current_participants = current_participants + 1,
    prize_pool = prize_pool + r.entry_fee::double precision,
    updated_at = now()
  where id = p_challenge_id;

  insert into public.wallet_transactions (user_id, type, amount, description)
  values (
    v_uid,
    'challenge_entry_fee',
    -r.entry_fee,
    concat('Challenge entry: ', left(r.title, 100))
  );
end;
$$;

grant execute on function public.join_challenge(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Update challenge media fields (creator video / thumbnails)
-- ---------------------------------------------------------------------------
create or replace function public.challenge_set_creator_video(
  p_challenge_id uuid,
  p_creator_video_url text,
  p_creator_thumbnail_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  update public.challenges
  set
    creator_video_url = p_creator_video_url,
    creator_thumbnail_url = coalesce(p_creator_thumbnail_url, creator_thumbnail_url),
    updated_at = now()
  where id = p_challenge_id
    and creator_id = v_uid;

  if not found then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.challenge_set_creator_video(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Upsert challenge submission (participant or creator video row)
-- Mirrors legacy addVideoToChallenge: may add uploader as participant without fee.
-- ---------------------------------------------------------------------------
create or replace function public.upsert_challenge_submission(
  p_challenge_id uuid,
  p_user_id uuid,
  p_video_id text,
  p_video_url text,
  p_title text,
  p_author_name text,
  p_is_creator_video boolean,
  p_thumbnail_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.challenges%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if v_uid <> p_user_id then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  select * into r from public.challenges where id = p_challenge_id for update;
  if not found then
    raise exception 'challenge_not_found' using errcode = 'P0001';
  end if;

  if not r.is_active then
    raise exception 'challenge_inactive' using errcode = 'P0001';
  end if;

  if not (v_uid = any (r.participants)) and v_uid <> r.creator_id then
    if r.current_participants >= r.max_participants then
      raise exception 'challenge_full' using errcode = 'P0001';
    end if;
    update public.challenges
    set
      participants = array_append(participants, v_uid),
      current_participants = current_participants + 1,
      updated_at = now()
    where id = p_challenge_id;
    select * into r from public.challenges where id = p_challenge_id;
  end if;

  insert into public.submissions (
    challenge_id, user_id, video_id, video_url, title, author_name,
    is_creator_video, thumbnail_url, is_active
  ) values (
    p_challenge_id, p_user_id, p_video_id, coalesce(p_video_url, ''),
    coalesce(p_title, ''), coalesce(p_author_name, ''),
    coalesce(p_is_creator_video, false), p_thumbnail_url, true
  )
  on conflict (challenge_id, user_id)
  do update set
    video_id = excluded.video_id,
    video_url = excluded.video_url,
    title = excluded.title,
    author_name = excluded.author_name,
    is_creator_video = excluded.is_creator_video,
    thumbnail_url = coalesce(excluded.thumbnail_url, public.submissions.thumbnail_url),
    updated_at = now();

  update public.challenges c
  set
    submission_user_ids = case
      when p_user_id = any (c.submission_user_ids) then c.submission_user_ids
      else array_append(c.submission_user_ids, p_user_id)
    end,
    updated_at = now()
  where c.id = p_challenge_id;
end;
$$;

grant execute on function public.upsert_challenge_submission(
  uuid, uuid, text, text, text, text, boolean, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Update submission thumbnail (after background generation)
-- ---------------------------------------------------------------------------
create or replace function public.challenge_submission_set_thumbnail(
  p_challenge_id uuid,
  p_user_id uuid,
  p_thumbnail_url text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  if v_uid <> p_user_id then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  update public.submissions
  set thumbnail_url = p_thumbnail_url, updated_at = now()
  where challenge_id = p_challenge_id and user_id = p_user_id;

  if not found then
    raise exception 'submission_not_found' using errcode = 'P0001';
  end if;

  update public.challenges
  set
    creator_thumbnail_url = p_thumbnail_url,
    updated_at = now()
  where id = p_challenge_id
    and creator_id = p_user_id;
end;
$$;

grant execute on function public.challenge_submission_set_thumbnail(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Cast vote on a submission (submission identified by author's user id)
-- p_award_coin: match legacy ChallengeVideoPlayer (+1 coin) vs details screen (0).
-- ---------------------------------------------------------------------------
create or replace function public.cast_challenge_vote(
  p_challenge_id uuid,
  p_submission_user_id uuid,
  p_rating double precision,
  p_award_coin boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.challenges%rowtype;
  v_vc int;
  v_ar double precision;
  v_new_c int;
  v_new_avg double precision;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if v_uid = p_submission_user_id then
    raise exception 'cannot_vote_self' using errcode = 'P0001';
  end if;

  if p_rating < 0 or p_rating > 5 then
    raise exception 'invalid_rating' using errcode = 'P0001';
  end if;

  select * into r from public.challenges where id = p_challenge_id;
  if not found then
    raise exception 'challenge_not_found' using errcode = 'P0001';
  end if;

  if r.status <> 'voting' then
    raise exception 'voting_not_open' using errcode = 'P0001';
  end if;

  select vote_count, average_rating into v_vc, v_ar
  from public.submissions
  where challenge_id = p_challenge_id and user_id = p_submission_user_id
  for update;

  if not found then
    raise exception 'submission_not_found' using errcode = 'P0001';
  end if;

  insert into public.challenge_votes (challenge_id, voter_id, submission_user_id, rating)
  values (p_challenge_id, v_uid, p_submission_user_id, p_rating);

  v_new_c := v_vc + 1;
  v_new_avg := (coalesce(v_ar, 0.0) * v_vc + p_rating) / nullif(v_new_c, 0);

  update public.submissions
  set
    vote_count = v_new_c,
    average_rating = coalesce(v_new_avg, 0),
    updated_at = now()
  where challenge_id = p_challenge_id and user_id = p_submission_user_id;

  if p_award_coin then
    update public.profiles
    set coins = coins + 1, updated_at = now()
    where id = v_uid;

    insert into public.wallet_transactions (user_id, type, amount, description)
    values (
      v_uid,
      'voting_reward',
      1,
      'Reward for voting in challenge'
    );
  end if;
end;
$$;

grant execute on function public.cast_challenge_vote(uuid, uuid, double precision, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Complete challenge (creator only, status must be voting)
-- ---------------------------------------------------------------------------
create or replace function public.complete_challenge(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r public.challenges%rowtype;
  v_pool double precision;
  v_pc int;
  v_prizes int[] := array[0, 0, 0];
  v_total int;
  v_first int;
  v_second int;
  v_third int;
  rec record;
  i int := 0;
  v_winner uuid;
  v_rating double precision;
  v_prize int;
  v_winners uuid[] := array[]::uuid[];
  v_scores jsonb := '{}'::jsonb;
  v_wp jsonb := '{}'::jsonb;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into r from public.challenges where id = p_challenge_id for update;
  if not found then
    raise exception 'challenge_not_found' using errcode = 'P0001';
  end if;

  if r.creator_id <> v_uid then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  if r.status = 'completed' then
    raise exception 'already_completed' using errcode = 'P0001';
  end if;

  if r.status <> 'voting' then
    raise exception 'not_in_voting' using errcode = 'P0001';
  end if;

  v_pool := case
    when r.prize_pool > 0 then r.prize_pool
    else greatest(coalesce(array_length(r.participants, 1), 0), r.current_participants) * r.entry_fee::double precision
  end;

  v_total := round(v_pool)::int;
  if v_total > 0 then
    v_first := round(v_total * 0.5)::int;
    v_second := round(v_total * 0.3)::int;
    v_third := greatest(v_total - v_first - v_second, 0);
    v_prizes := array[v_first, v_second, v_third];
  end if;

  for rec in
    select s.user_id, s.average_rating
    from public.submissions s
    where s.challenge_id = p_challenge_id
      and s.is_active = true
    order by s.average_rating desc nulls last, s.created_at asc
    limit 3
  loop
    i := i + 1;
    exit when i > 3;
    v_winner := rec.user_id;
    v_rating := coalesce(rec.average_rating, 0.0);
    v_prize := v_prizes[i];

    v_winners := array_append(v_winners, v_winner);
    v_scores := v_scores || jsonb_build_object(v_winner::text, v_rating);
    v_wp := v_wp || jsonb_build_object(v_winner::text, v_prize);

    if v_prize > 0 then
      update public.profiles
      set coins = coins + v_prize, updated_at = now()
      where id = v_winner;

      insert into public.wallet_transactions (user_id, type, amount, description)
      values (
        v_winner,
        'challenge_prize',
        v_prize,
        concat('Prize place ', i, ' in challenge: ', left(r.title, 80))
      );
    end if;
  end loop;

  update public.challenges
  set
    status = 'completed',
    winners = v_winners,
    final_scores = v_scores,
    winner_prizes = v_wp,
    is_active = false,
    completed_at = now(),
    updated_at = now()
  where id = p_challenge_id;
end;
$$;

grant execute on function public.complete_challenge(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Delete challenge (creator only)
-- ---------------------------------------------------------------------------
create or replace function public.delete_challenge(p_challenge_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  delete from public.challenges
  where id = p_challenge_id
    and creator_id = v_uid;

  if not found then
    raise exception 'challenge_not_found_or_forbidden' using errcode = 'P0001';
  end if;
end;
$$;

grant execute on function public.delete_challenge(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin wipe: include new tables
-- ---------------------------------------------------------------------------
create or replace function public.admin_delete_all_challenge_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and is_admin is true
  ) then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  truncate table
    public.challenge_celebration_ack,
    public.challenge_votes,
    public.submissions,
    public.challenges
  cascade;
end;
$$;
