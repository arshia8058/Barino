-- Manual application of the admin-console migration: part 7 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

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
