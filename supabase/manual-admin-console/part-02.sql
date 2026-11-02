-- Manual application of the admin-console migration: part 2 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

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
