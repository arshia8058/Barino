-- Manual application of the admin-console migration: part 5 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

create or replace function public.admin_set_user_blocked(p_user_id uuid, p_blocked boolean)
returns void
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_currently_blocked boolean;
begin
  v_actor := public.admin_require_access();
  if p_user_id is null or p_blocked is null then
    raise exception using errcode = '22023', message = 'User and requested status are required';
  end if;
  if p_user_id = v_actor then
    raise exception using errcode = '42501', message = 'An administrator cannot block their own account';
  end if;
  if exists (select 1 from public.app_admins a where a.user_id = p_user_id) then
    raise exception using errcode = '42501', message = 'Administrator accounts are managed only by the project owner';
  end if;

  select p.is_blocked into v_currently_blocked
    from public.profiles p where p.id = p_user_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'User not found';
  end if;
  if v_currently_blocked = p_blocked then
    return;
  end if;
  update public.profiles set is_blocked = p_blocked where id = p_user_id;
end;
$$;

create or replace function public.admin_list_loads(
  p_search text default null,
  p_status text default 'all',
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_search text := lower(btrim(coalesce(p_search, '')));
  v_status text := lower(btrim(coalesce(p_status, 'all')));
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000000);
  v_result jsonb;
begin
  v_actor := public.admin_require_access();
  if v_status <> 'all' and v_status not in ('published', 'receiving_offers', 'agreed', 'awaiting_pickup', 'in_transit', 'delivered', 'cancelled') then
    raise exception using errcode = '22023', message = 'Invalid load status filter';
  end if;

  with filtered as (
    select l.id as load_id,
           l.owner_id,
           p.display_name as owner_name,
           p.phone as owner_phone,
           u.email as owner_email,
           l.title,
           l.cargo_description,
           l.origin_city,
           l.destination_city,
           l.weight_value,
           l.weight_unit,
           l.cargo_type,
           l.required_truck_type,
           l.proposed_fare,
           l.loading_date,
           l.notes,
           l.status::text as status,
           l.created_at,
           l.updated_at
      from public.loads l
      join public.profiles p on p.id = l.owner_id
      join auth.users u on u.id = p.id
     where (v_search = '' or strpos(lower(concat_ws(' ', l.id::text, l.title, l.origin_city, l.destination_city, p.display_name, p.phone, u.email)), v_search) > 0)
       and (v_status = 'all' or l.status::text = v_status)
  ), page as (
    select * from filtered order by created_at desc, load_id desc limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(to_jsonb(pg) order by pg.created_at desc, pg.load_id desc) from page pg), '[]'::jsonb),
    'total', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset
  ) into v_result;
  return v_result;
end;
$$;

