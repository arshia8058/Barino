-- Barino admin console: additive migration.
-- Uses the existing private app_admins membership table as the only admin authority.
-- Never grant the browser/service_role key any administrator identity through profiles or metadata.

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (action in (
    'user_blocked', 'user_unblocked', 'user_role_changed', 'load_cancelled',
    'load_status_changed', 'report_resolved', 'report_dismissed', 'report_reopened'
  )),
  target_type text not null check (target_type in ('user', 'load', 'report')),
  target_id uuid not null,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_idx
  on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_target_idx
  on public.admin_audit_log (target_type, target_id, created_at desc);

alter table public.admin_audit_log enable row level security;

drop policy if exists admin_audit_log_select_admin on public.admin_audit_log;
create policy admin_audit_log_select_admin
  on public.admin_audit_log for select to authenticated
  using (public.is_active_user() and public.is_admin());
revoke all on table public.admin_audit_log from public, anon, authenticated;
grant select on table public.admin_audit_log to authenticated;
-- All report status changes must pass through the guarded/audited RPC below.
revoke update on table public.reports from authenticated;
drop policy if exists reports_update_admin on public.reports;

-- Fail closed unless exactly one database-owner-selected administrator exists.
-- This preserves the existing membership table but prevents accidental multiple admins.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select auth.uid() is not null
     and (select count(*) = 1 from public.app_admins)
     and exists (select 1 from public.app_admins a where a.user_id = auth.uid());
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- Internal guard; never callable directly by anon/authenticated clients.
create or replace function public.admin_require_access()
returns uuid
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null
     or not coalesce(public.is_active_user(), false)
     or not coalesce(public.is_admin(), false) then
    raise exception using errcode = '42501', message = 'ADMIN_ACCESS_DENIED';
  end if;
  return v_actor;
end;
$$;
revoke all on function public.admin_require_access() from public, anon, authenticated;

-- Audit privileged row changes too, including direct REST UPDATEs by an administrator.
-- Ordinary users do not create these records, and the audit table has no client INSERT grant.
create or replace function public.audit_admin_managed_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_action text;
begin
  if v_actor is null
     or not coalesce(public.is_active_user(), false)
     or not coalesce(public.is_admin(), false) then
    return new;
  end if;

  if tg_table_name = 'profiles' then
    if new.is_blocked is distinct from old.is_blocked then
      v_action := case when new.is_blocked then 'user_blocked' else 'user_unblocked' end;
      insert into public.admin_audit_log (actor_id, action, target_type, target_id)
      values (v_actor, v_action, 'user', new.id);
    end if;
    if new.role is distinct from old.role then
      insert into public.admin_audit_log (actor_id, action, target_type, target_id)
      values (v_actor, 'user_role_changed', 'user', new.id);
    end if;
  elsif tg_table_name = 'loads' and new.status is distinct from old.status then
    v_action := case when new.status = 'cancelled' then 'load_cancelled' else 'load_status_changed' end;
    insert into public.admin_audit_log (actor_id, action, target_type, target_id)
    values (v_actor, v_action, 'load', new.id);
  elsif tg_table_name = 'reports' and new.status is distinct from old.status then
    v_action := case new.status
      when 'resolved' then 'report_resolved'
      when 'dismissed' then 'report_dismissed'
      else 'report_reopened'
    end;
    insert into public.admin_audit_log (actor_id, action, target_type, target_id)
    values (v_actor, v_action, 'report', new.id);
  end if;
  return new;
end;
$$;
revoke all on function public.audit_admin_managed_update() from public, anon, authenticated;

-- Stop an administrator from locking out or changing the profile role of any administrator.
create or replace function public.prevent_admin_profile_lockout()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if auth.uid() is not null
     and exists (select 1 from public.app_admins a where a.user_id = old.id)
     and (new.is_blocked is distinct from old.is_blocked or new.role is distinct from old.role) then
    raise exception using errcode = '42501', message = 'Administrator membership/profile status is managed only by the project owner';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_admin_profile_lockout() from public, anon, authenticated;

drop trigger if exists profiles_admin_membership_guard on public.profiles;
create trigger profiles_admin_membership_guard before update on public.profiles
  for each row execute function public.prevent_admin_profile_lockout();

-- A manager may update their own ordinary profile fields, or change only is_blocked on another account.
create or replace function public.prevent_admin_profile_overreach()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if auth.uid() is not null
     and auth.uid() is distinct from old.id
     and public.is_admin()
     and (to_jsonb(new) - 'is_blocked' - 'updated_at') is distinct from (to_jsonb(old) - 'is_blocked' - 'updated_at') then
    raise exception using errcode = '42501', message = 'Administrators may change only another account blocked status';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_admin_profile_overreach() from public, anon, authenticated;
drop trigger if exists profiles_admin_overreach on public.profiles;
create trigger profiles_admin_overreach before update on public.profiles
  for each row execute function public.prevent_admin_profile_overreach();

drop trigger if exists profiles_admin_audit on public.profiles;
create trigger profiles_admin_audit after update on public.profiles
  for each row execute function public.audit_admin_managed_update();
drop trigger if exists loads_admin_audit on public.loads;
create trigger loads_admin_audit after update on public.loads
  for each row execute function public.audit_admin_managed_update();
drop trigger if exists reports_admin_audit on public.reports;
create trigger reports_admin_audit after update on public.reports
  for each row execute function public.audit_admin_managed_update();

-- Direct administrator table updates are narrower than the full admin API:
-- only the approved open-load -> cancelled transition is allowed from the browser.
create or replace function public.prevent_admin_load_overreach()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if auth.uid() is not null and public.is_admin() then
    if (to_jsonb(new) - 'status' - 'updated_at') is distinct from (to_jsonb(old) - 'status' - 'updated_at') then
      raise exception using errcode = '42501', message = 'Administrators cannot edit load content through direct table updates';
    end if;
    if new.status is distinct from old.status
       and not (old.status in ('published', 'receiving_offers') and new.status = 'cancelled') then
      raise exception using errcode = '42501', message = 'Only open loads may be deactivated by an administrator';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_admin_load_overreach() from public, anon, authenticated;
drop trigger if exists loads_admin_overreach on public.loads;
create trigger loads_admin_overreach before update on public.loads
  for each row execute function public.prevent_admin_load_overreach();

create or replace function public.admin_get_session_info()
returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_email text;
  v_confirmed_at timestamptz;
begin
  v_actor := public.admin_require_access();
  select u.email, u.email_confirmed_at into v_email, v_confirmed_at
    from auth.users u where u.id = v_actor;
  return jsonb_build_object(
    'user_id', v_actor,
    'email', v_email,
    'email_verified', v_confirmed_at is not null,
    'access', 'administrator',
    'database_status', 'connected',
    'checked_at', clock_timestamp()
  );
end;
$$;

create or replace function public.admin_get_dashboard_summary()
returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
begin
  v_actor := public.admin_require_access();
  return jsonb_build_object(
    'users_total', (select count(*) from public.profiles),
    'drivers_total', (select count(*) from public.profiles where role = 'driver'),
    'cargo_owners_total', (select count(*) from public.profiles where role = 'cargo_owner'),
    'loads_total', (select count(*) from public.loads),
    'loads_open', (select count(*) from public.loads where status in ('published', 'receiving_offers')),
    'shipments_active', (select count(*) from public.shipments where status in ('agreed', 'awaiting_pickup', 'in_transit')),
    'shipments_delivered', (select count(*) from public.shipments where status = 'delivered'),
    'reports_open', (select count(*) from public.reports where status = 'open'),
    'checked_at', clock_timestamp()
  );
end;
$$;

create or replace function public.admin_list_activity(p_limit integer default 12)
returns table (
  event_id text,
  event_type text,
  occurred_at timestamptz,
  target_id uuid,
  actor_id uuid,
  description text
)
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_limit integer := least(greatest(coalesce(p_limit, 12), 1), 50);
begin
  v_actor := public.admin_require_access();
  return query
    select events.event_id, events.event_type, events.occurred_at,
           events.target_id, events.actor_id, events.description
    from (
      select 'admin-' || a.id::text as event_id,
             'admin_action'::text as event_type,
             a.created_at as occurred_at,
             a.target_id,
             a.actor_id,
             a.action::text as description
        from public.admin_audit_log a
      union all
      select 'load-' || l.id::text,
             'load_created'::text,
             l.created_at,
             l.id,
             l.owner_id,
             'load_created'::text
        from public.loads l
      union all
      select 'shipment-' || h.id::text,
             'shipment_status'::text,
             h.created_at,
             h.shipment_id,
             h.changed_by,
             h.new_status::text
        from public.shipment_status_history h
      union all
      select 'report-' || r.id::text,
             'report_created'::text,
             r.created_at,
             r.id,
             r.reporter_id,
             'report_created'::text
        from public.reports r
    ) as events
    order by events.occurred_at desc, events.event_id desc
    limit v_limit;
end;
$$;

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

create or replace function public.admin_list_reports(
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
  if v_status <> 'all' and v_status not in ('open', 'resolved', 'dismissed') then
    raise exception using errcode = '22023', message = 'Invalid report status filter';
  end if;
  with filtered as (
    select r.id as report_id,
           r.reporter_id,
           p.display_name as reporter_name,
           u.email as reporter_email,
           p.phone as reporter_phone,
           r.subject,
           r.description,
           r.target_id,
           r.status::text as status,
           r.resolved_by,
           r.resolved_at,
           r.created_at,
           r.updated_at
      from public.reports r
      join public.profiles p on p.id = r.reporter_id
      join auth.users u on u.id = r.reporter_id
     where (v_search = '' or strpos(lower(concat_ws(' ', r.id::text, r.subject, r.description, p.display_name, p.phone, u.email)), v_search) > 0)
       and (v_status = 'all' or r.status::text = v_status)
  ), page as (
    select * from filtered order by created_at desc, report_id desc limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(to_jsonb(pg) order by pg.created_at desc, pg.report_id desc) from page pg), '[]'::jsonb),
    'total', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.admin_get_report_detail(p_report_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_report jsonb;
begin
  v_actor := public.admin_require_access();
  select jsonb_build_object(
    'report_id', r.id,
    'reporter_id', r.reporter_id,
    'reporter_name', p.display_name,
    'reporter_email', u.email,
    'reporter_phone', p.phone,
    'subject', r.subject,
    'description', r.description,
    'target_id', r.target_id,
    'status', r.status::text,
    'resolved_by', r.resolved_by,
    'resolved_at', r.resolved_at,
    'created_at', r.created_at,
    'updated_at', r.updated_at
  ) into v_report
  from public.reports r
  join public.profiles p on p.id = r.reporter_id
  join auth.users u on u.id = r.reporter_id
  where r.id = p_report_id;
  if v_report is null then
    raise exception using errcode = 'P0002', message = 'Report not found';
  end if;
  return v_report;
end;
$$;

create or replace function public.admin_resolve_report(p_report_id uuid, p_resolution text default 'resolved')
returns void
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_actor uuid;
  v_status public.report_status;
begin
  v_actor := public.admin_require_access();
  if p_resolution is null or p_resolution not in ('resolved', 'dismissed') then
    raise exception using errcode = '22023', message = 'Invalid report resolution';
  end if;
  select r.status into v_status from public.reports r where r.id = p_report_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Report not found';
  end if;
  if v_status <> 'open' then
    raise exception using errcode = '22023', message = 'Report is already closed';
  end if;
  update public.reports
     set status = p_resolution::public.report_status,
         resolved_at = clock_timestamp(),
         resolved_by = v_actor
   where id = p_report_id;
end;
$$;

-- Explicit execute grants: Postgres defaults new functions to PUBLIC EXECUTE.
revoke all on function public.admin_get_session_info() from public, anon;
revoke all on function public.admin_get_dashboard_summary() from public, anon;
revoke all on function public.admin_list_activity(integer) from public, anon;
revoke all on function public.admin_list_users(text, text, text, integer, integer) from public, anon;
revoke all on function public.admin_get_user_detail(uuid) from public, anon;
revoke all on function public.admin_set_user_blocked(uuid, boolean) from public, anon;
revoke all on function public.admin_list_loads(text, text, integer, integer) from public, anon;
revoke all on function public.admin_get_load_detail(uuid) from public, anon;
revoke all on function public.admin_cancel_load(uuid) from public, anon;
revoke all on function public.admin_list_shipments(text, text, integer, integer) from public, anon;
revoke all on function public.admin_list_reports(text, text, integer, integer) from public, anon;
revoke all on function public.admin_get_report_detail(uuid) from public, anon;
revoke all on function public.admin_resolve_report(uuid, text) from public, anon;

grant execute on function public.admin_get_session_info() to authenticated;
grant execute on function public.admin_get_dashboard_summary() to authenticated;
grant execute on function public.admin_list_activity(integer) to authenticated;
grant execute on function public.admin_list_users(text, text, text, integer, integer) to authenticated;
grant execute on function public.admin_get_user_detail(uuid) to authenticated;
grant execute on function public.admin_set_user_blocked(uuid, boolean) to authenticated;
grant execute on function public.admin_list_loads(text, text, integer, integer) to authenticated;
grant execute on function public.admin_get_load_detail(uuid) to authenticated;
grant execute on function public.admin_cancel_load(uuid) to authenticated;
grant execute on function public.admin_list_shipments(text, text, integer, integer) to authenticated;
grant execute on function public.admin_list_reports(text, text, integer, integer) to authenticated;
grant execute on function public.admin_get_report_detail(uuid) to authenticated;
grant execute on function public.admin_resolve_report(uuid, text) to authenticated;
