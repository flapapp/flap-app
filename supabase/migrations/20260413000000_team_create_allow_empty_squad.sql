-- Allow creating a club with zero squad rows (fill squad later).
create or replace function public.team_create_with_squad(
  p_name text,
  p_description text,
  p_city text,
  p_is_public boolean,
  p_short_name text,
  p_founded_year integer,
  p_country text,
  p_primary_color text,
  p_secondary_color text,
  p_players jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_elem jsonb;
  v_pos public.player_position;
  v_name text;
  v_jersey int;
  v_age int;
  v_nat text;
  v_len int;
  v_distinct int;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if p_players is null or jsonb_typeof(p_players) <> 'array' then
    raise exception 'invalid_players' using errcode = 'P0001';
  end if;

  v_len := jsonb_array_length(p_players);

  if v_len > 0 then
    select count(*)::int into v_distinct
    from (
      select distinct (e->>'jersey_number')::int as j
      from jsonb_array_elements(p_players) e
    ) s;

    if v_distinct <> v_len then
      raise exception 'duplicate_jersey' using errcode = 'P0001';
    end if;
  end if;

  v_id := public.team_create(
    p_name,
    coalesce(p_description, ''),
    p_city,
    coalesce(p_is_public, true)
  );

  update public.teams
  set
    short_name = nullif(trim(p_short_name), ''),
    founded_year = p_founded_year,
    country = nullif(trim(p_country), ''),
    primary_color = nullif(trim(p_primary_color), ''),
    secondary_color = nullif(trim(p_secondary_color), ''),
    updated_at = now()
  where id = v_id;

  if v_len > 0 then
    for v_elem in select * from jsonb_array_elements(p_players)
    loop
      v_name := coalesce(nullif(trim(v_elem->>'name'), ''), 'Player');
      v_pos := (v_elem->>'position')::public.player_position;
      v_jersey := (v_elem->>'jersey_number')::int;
      v_age := nullif(v_elem->>'age', '')::int;
      v_nat := nullif(trim(v_elem->>'nationality'), '');

      insert into public.players (
        team_id, user_id, name, position, jersey_number, age, nationality
      ) values (
        v_id, v_uid, v_name, v_pos, v_jersey, v_age, v_nat
      );
    end loop;
  end if;

  return v_id;
end;
$$;
