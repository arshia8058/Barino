-- Manual application of the admin-console migration: part 1 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

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
