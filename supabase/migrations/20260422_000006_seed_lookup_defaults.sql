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
