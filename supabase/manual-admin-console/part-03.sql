-- Manual application of the admin-console migration: part 3 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

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

