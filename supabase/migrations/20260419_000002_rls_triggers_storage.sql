-- =============================================================================
-- RLS, helpers, triggers, storage (run AFTER 20260417_000001_initial_schema.sql)
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
