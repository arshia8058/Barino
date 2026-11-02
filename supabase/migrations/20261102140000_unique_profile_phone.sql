-- Enforce phone-number uniqueness across every profile role.
-- Supported Iranian mobile formats are normalized to 09xxxxxxxxx before storage; legacy local 9xxxxxxxxx values are also reconciled.
-- This migration deliberately does not rewrite existing profile data. It stops
-- with a clear error if normalized duplicates need to be resolved first.

create or replace function public.canonical_profile_phone(p_phone text)
returns text
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  v_phone text;
begin
  if p_phone is null then
    return null;
  end if;

  v_phone := regexp_replace(
    translate(p_phone, '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'),
    '[[:space:]-]',
    '',
    'g'
  );

  if v_phone = '' then
    return null;
  elsif v_phone ~ '^9[0-9]{9}$' then
    return '0' || v_phone;
  elsif v_phone ~ '^[+]989[0-9]{9}$' then
    return '0' || substring(v_phone from 4);
  elsif v_phone ~ '^00989[0-9]{9}$' then
    return '0' || substring(v_phone from 5);
  end if;

  -- Preserve invalid legacy values for preflight visibility; new writes remain
  -- subject to the existing phone-format check constraints.
  return v_phone;
end;
$$;

revoke all on function public.canonical_profile_phone(text) from public, anon;
grant execute on function public.canonical_profile_phone(text) to authenticated, service_role;


-- Stop before creating the index rather than choosing which account keeps a
-- shared number. Check canonical values so 09..., +989..., and 00989... collide.
do $$
begin
  if exists (
    select 1
    from public.profiles p
    where public.canonical_profile_phone(p.phone) is not null
    group by public.canonical_profile_phone(p.phone)
    having count(*) > 1
  ) then
    raise exception using
      errcode = '23505',
      message = 'Cannot enforce profile phone uniqueness: duplicate canonical phone numbers exist. Resolve the duplicate profiles, then rerun this migration.';
  end if;
end;
$$;

create unique index if not exists profiles_phone_canonical_unique_idx
  on public.profiles (public.canonical_profile_phone(phone))
  where phone is not null
    and public.canonical_profile_phone(phone) is not null;

create or replace function public.normalize_profile_phone()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.phone := public.canonical_profile_phone(new.phone);
  return new;
end;
$$;
revoke all on function public.normalize_profile_phone() from public, anon, authenticated;

drop trigger if exists profiles_phone_normalize on public.profiles;
create trigger profiles_phone_normalize
before insert or update of phone on public.profiles
for each row execute function public.normalize_profile_phone();

comment on index public.profiles_phone_canonical_unique_idx is
  'Enforces one canonical Iranian mobile number across all profile roles.';
