-- Manual application of the admin-console migration: part 6 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

create or replace function public.admin_get_load_detail(p_load_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_load public.loads%rowtype;
  v_owner jsonb;
  v_private_details jsonb;
begin
  v_actor := public.admin_require_access();
  select l.* into v_load from public.loads l where l.id = p_load_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'Load not found';
  end if;
  select jsonb_build_object(
           'user_id', p.id,
           'display_name', p.display_name,
           'email', u.email,
           'phone', p.phone,
           'city', p.city
         ) into v_owner
    from public.profiles p join auth.users u on u.id = p.id
   where p.id = v_load.owner_id;
  select jsonb_build_object('pickup_address', d.pickup_address, 'delivery_address', d.delivery_address)
    into v_private_details from public.load_private_details d where d.load_id = p_load_id;
  return jsonb_build_object(
    'load', to_jsonb(v_load),
    'owner', coalesce(v_owner, '{}'::jsonb),
    'private_details', coalesce(v_private_details, '{}'::jsonb)
  );
end;
$$;

create or replace function public.admin_cancel_load(p_load_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_status public.load_status;
begin
  v_actor := public.admin_require_access();
  select l.status into v_status from public.loads l where l.id = p_load_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Load not found';
  end if;
  if v_status not in ('published', 'receiving_offers') then
    raise exception using errcode = '22023', message = 'Only an open load can be deactivated';
  end if;
  update public.loads set status = 'cancelled' where id = p_load_id;
  update public.freight_offers set status = 'declined'
   where load_id = p_load_id and status = 'submitted';
end;
$$;

create or replace function public.admin_list_shipments(
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
  if v_status <> 'all' and v_status not in ('agreed', 'awaiting_pickup', 'in_transit', 'delivered', 'cancelled') then
    raise exception using errcode = '22023', message = 'Invalid shipment status filter';
  end if;
  with filtered as (
    select s.id as shipment_id,
           s.load_id,
           s.status::text as status,
           s.agreed_fare,
           s.created_at,
           s.updated_at,
           l.title as load_title,
           l.origin_city,
           l.destination_city,
           l.loading_date,
           s.owner_id,
           owner_profile.display_name as owner_name,
           owner_user.email as owner_email,
           s.driver_id,
           driver_profile.display_name as driver_name,
           driver_user.email as driver_email
      from public.shipments s
      join public.loads l on l.id = s.load_id
      join public.profiles owner_profile on owner_profile.id = s.owner_id
      join auth.users owner_user on owner_user.id = s.owner_id
      join public.profiles driver_profile on driver_profile.id = s.driver_id
      join auth.users driver_user on driver_user.id = s.driver_id
     where (v_search = '' or strpos(lower(concat_ws(' ', s.id::text, l.title, l.origin_city, l.destination_city, owner_profile.display_name, owner_user.email, driver_profile.display_name, driver_user.email)), v_search) > 0)
       and (v_status = 'all' or s.status::text = v_status)
  ), page as (
    select * from filtered order by created_at desc, shipment_id desc limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(to_jsonb(pg) order by pg.created_at desc, pg.shipment_id desc) from page pg), '[]'::jsonb),
    'total', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset
  ) into v_result;
  return v_result;
end;
$$;

