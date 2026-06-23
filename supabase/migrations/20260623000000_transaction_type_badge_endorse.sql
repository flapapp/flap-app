-- The skill-badge endorsement flow (player_badge_endorsement_repository_impl)
-- records a coin ledger entry of type 'badge_endorse'. That code was never
-- seeded into transaction_types, so the client lookup missed and fell back to
-- an INSERT that the admin-only RLS policy (transaction_types_write_admin)
-- rejects with code 42501. Seed the row so the lookup resolves by SELECT.

insert into public.transaction_types (code, label)
values ('badge_endorse', 'Badge endorsement')
on conflict (code) do update set label = excluded.label;
