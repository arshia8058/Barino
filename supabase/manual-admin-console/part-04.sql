-- Manual application of the admin-console migration: part 4 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

create or replace function public.admin_list_users(
  p_search text default null,
  p_role text default 'all',
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
  v_role text := lower(btrim(coalesce(p_role, 'all')));
  v_status text := lower(btrim(coalesce(p_status, 'all')));
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000000);
  v_result jsonb;
begin
  v_actor := public.admin_require_access();
  if v_role not in ('all', 'driver', 'cargo_owner') then
    raise exception using errcode = '22023', message = 'Invalid role filter';
  end if;
  if v_status not in ('all', 'active', 'blocked', 'unverified') then
    raise exception using errcode = '22023', message = 'Invalid user status filter';
  end if;

  with filtered as (
    select p.id as user_id,
           u.email,
           u.email_confirmed_at,
           u.last_sign_in_at,
           p.display_name,
           p.phone,
           p.role::text as role,
           p.city,
           p.truck_type,
           p.truck_model,
           p.plate_number,
           p.is_blocked,
           p.created_at,
           p.updated_at,
           exists (select 1 from public.app_admins a where a.user_id = p.id) as is_admin
      from public.profiles p
      join auth.users u on u.id = p.id
     where (v_search = '' or strpos(lower(concat_ws(' ', p.id::text, p.display_name, p.phone, p.city, u.email)), v_search) > 0)
       and (v_role = 'all' or p.role::text = v_role)
       and (v_status = 'all'
            or (v_status = 'active' and not p.is_blocked and u.email_confirmed_at is not null)
            or (v_status = 'blocked' and p.is_blocked)
            or (v_status = 'unverified' and u.email_confirmed_at is null))
  ), page as (
    select * from filtered order by created_at desc, user_id desc limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(to_jsonb(pg) order by pg.created_at desc, pg.user_id desc) from page pg), '[]'::jsonb),
    'total', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.admin_get_user_detail(p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_profile public.profiles%rowtype;
  v_email text;
  v_confirmed_at timestamptz;
  v_last_sign_in_at timestamptz;
  v_is_admin boolean;
begin
  v_actor := public.admin_require_access();
  select p.* into v_profile from public.profiles p where p.id = p_user_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'User not found';
  end if;
  select u.email, u.email_confirmed_at, u.last_sign_in_at
    into v_email, v_confirmed_at, v_last_sign_in_at
    from auth.users u where u.id = p_user_id;
  select exists (select 1 from public.app_admins a where a.user_id = p_user_id) into v_is_admin;
  return jsonb_build_object(
    'user_id', v_profile.id,
    'email', v_email,
    'email_confirmed_at', v_confirmed_at,
    'last_sign_in_at', v_last_sign_in_at,
    'display_name', v_profile.display_name,
    'phone', v_profile.phone,
    'role', v_profile.role::text,
    'city', v_profile.city,
    'truck_type', v_profile.truck_type,
    'truck_model', v_profile.truck_model,
    'plate_number', v_profile.plate_number,
    'is_blocked', v_profile.is_blocked,
    'is_admin', v_is_admin,
    'created_at', v_profile.created_at,
    'updated_at', v_profile.updated_at
  );
end;
$$;

