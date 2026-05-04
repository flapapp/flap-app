-- Replace current skill badges with the requested football skills list.
-- Keeps non-skill badges intact.
-- NOTE: Deleting old skill badges cascades to public.user_badges for those badges.

begin;

with requested_skills(code, name, description, category, emoji, price, is_available) as (
  values
    ('dribbling_skill', 'Dribbling', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🕺', 10, true),
    ('volley_skill', 'Volley', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🥏', 10, true),
    ('nutmeg_skill', 'Nutmeg', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🥜', 10, true),
    ('header_skill', 'Header', 'Shown on your profile; other players can confirm this football skill.', 'skill', '⚽', 10, true),
    ('long_pass_skill', 'Long pass', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🛰️', 10, true),
    ('short_pass_skill', 'Short pass', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🔗', 10, true),
    ('heel_pass_skill', 'Heel pass', 'Shown on your profile; other players can confirm this football skill.', 'skill', '👟', 10, true),
    ('chest_control_skill', 'Chest control', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🤲', 10, true),
    ('juggling_skill', 'Juggling', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🤹', 10, true),
    ('cruyff_turn_skill', 'Cruyff turn', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🌀', 10, true),
    ('near_post_shot_skill', 'Near post shot', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🥅', 10, true),
    ('far_post_shot_skill', 'Far post shot', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🎯', 10, true),
    ('goal_from_corner_skill', 'Goal from a corner', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🚩', 10, true),
    ('free_kick_skill', 'Free kick', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🌪️', 10, true),
    ('penalty_skill', 'Penalty', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🎯', 10, true),
    ('one_on_one_breakaway_skill', 'One-on-one breakaway', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🏃', 10, true),
    ('cross_skill', 'Cross', 'Shown on your profile; other players can confirm this football skill.', 'skill', '📐', 10, true),
    ('beating_defender_skill', 'Beating a defender', 'Shown on your profile; other players can confirm this football skill.', 'skill', '💨', 10, true),
    ('slide_tackle_skill', 'Slide tackle', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🛷', 10, true),
    ('interception_skill', 'Interception', 'Shown on your profile; other players can confirm this football skill.', 'skill', '✋', 10, true),
    ('ball_clearance_skill', 'Ball clearance', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🧱', 10, true),
    ('positional_defending_skill', 'Positional defending', 'Shown on your profile; other players can confirm this football skill.', 'skill', '📍', 10, true),
    ('pressing_skill', 'Pressing', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🧲', 10, true),
    ('penalty_save_skill', 'Penalty save', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🧤', 10, true),
    ('one_on_one_save_skill', 'One-on-one save', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🥅', 10, true),
    ('throw_in_distribution_skill', 'Throw-in distribution', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🤾', 10, true),
    ('goal_kick_skill', 'Goal kick', 'Shown on your profile; other players can confirm this football skill.', 'skill', '⚡', 10, true),
    ('explosive_acceleration_skill', 'Explosive acceleration', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🚀', 10, true),
    ('jumping_for_ball_skill', 'Jumping for the ball', 'Shown on your profile; other players can confirm this football skill.', 'skill', '🦘', 10, true),
    ('change_of_running_direction_skill', 'Change of running direction', 'Shown on your profile; other players can confirm this football skill.', 'skill', '↩️', 10, true)
),
upsert_requested as (
  insert into public.badges (code, name, description, category, emoji, price, is_available)
  select code, name, description, category, emoji, price, is_available
  from requested_skills
  on conflict (code) do update
  set
    name = excluded.name,
    description = excluded.description,
    category = excluded.category,
    emoji = excluded.emoji,
    price = excluded.price,
    is_available = excluded.is_available,
    updated_at = now()
  returning code
)
delete from public.badges b
where b.category = 'skill'
  and not exists (
    select 1
    from requested_skills rs
    where rs.code = b.code
  );

commit;
