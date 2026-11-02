-- Run only in Supabase SQL Editor as the project/database owner.
-- First inspect existing administrator memberships; this script never removes them.
select a.user_id, u.email, u.email_confirmed_at, a.created_at
from public.app_admins a
join auth.users u on u.id = a.user_id
order by a.created_at;

-- Replace the placeholder below with the exact email of an already-created,
-- email-verified Supabase Auth account. No default account is created.
do $$
declare
  v_admin_email text := lower(btrim('REPLACE_WITH_VERIFIED_OWNER_EMAIL'));
  v_admin_id uuid;
  v_matches integer;
begin
  if v_admin_email = '' or v_admin_email = 'replace_with_verified_owner_email' then
    raise exception 'Set the exact verified administrator email before running this block';
  end if;

  select count(*)::integer
    into v_matches
    from auth.users u
   where lower(u.email) = v_admin_email
     and u.email_confirmed_at is not null;

  if v_matches <> 1 then
    raise exception 'Expected exactly one existing verified Auth account for the selected email; found %', v_matches;
  end if;

  select u.id into v_admin_id
    from auth.users u
   where lower(u.email) = v_admin_email
     and u.email_confirmed_at is not null;

  if not exists (
    select 1 from public.profiles p where p.id = v_admin_id and not p.is_blocked
  ) then
    raise exception 'Selected Auth account must have an active, unblocked Barino profile before it can administer the console';
  end if;

  if exists (select 1 from public.app_admins a where a.user_id <> v_admin_id) then
    raise exception 'Another administrator membership exists; review and explicitly revoke it before provisioning a single owner account';
  end if;

  insert into public.app_admins (user_id)
  values (v_admin_id)
  on conflict (user_id) do nothing;
end;
$$;

-- Verify the selected account. Review this output before closing SQL Editor.
select a.user_id, u.email, u.email_confirmed_at, a.created_at
from public.app_admins a
join auth.users u on u.id = a.user_id
where lower(u.email) = lower('REPLACE_WITH_VERIFIED_OWNER_EMAIL');
