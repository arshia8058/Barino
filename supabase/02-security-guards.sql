create or replace function public.guard_profile_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'شناسه پروفایل قابل تغییر نیست';
  end if;
  if new.role is distinct from old.role and not public.is_admin() then
    raise exception 'نقش حساب قابل تغییر نیست';
  end if;
  if new.is_blocked is distinct from old.is_blocked and not public.is_admin() then
    raise exception 'وضعیت مسدودی فقط توسط مدیر تغییر می‌کند';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.guard_load_update()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  transition text := current_setting('app.barino_transition', true);
begin
  if new.owner_id is distinct from old.owner_id then
    raise exception 'مالک بار قابل تغییر نیست';
  end if;
  if not public.is_admin() and old.status not in ('published', 'receiving_offers') and transition <> 'shipment' then
    raise exception 'بار نهایی‌شده قابل ویرایش نیست';
  end if;
  if new.status is distinct from old.status and not public.is_admin() then
    if transition = 'offer' and old.status = 'published' and new.status = 'receiving_offers' then
      null;
    elsif transition = 'accept' and old.status in ('published', 'receiving_offers') and new.status = 'agreed' then
      null;
    elsif transition = 'shipment' and ((old.status = 'agreed' and new.status = 'awaiting_pickup') or (old.status = 'awaiting_pickup' and new.status = 'in_transit') or (old.status = 'in_transit' and new.status = 'delivered')) then
      null;
    elsif auth.uid() = old.owner_id and old.status in ('published', 'receiving_offers') and new.status = 'cancelled' then
      null;
    else
      raise exception 'تغییر وضعیت بار مجاز نیست';
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.guard_shipment_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.load_id is distinct from old.load_id or new.offer_id is distinct from old.offer_id
     or new.owner_id is distinct from old.owner_id or new.driver_id is distinct from old.driver_id
     or new.agreed_fare is distinct from old.agreed_fare then
    raise exception 'مشخصات اصلی سفارش قابل تغییر نیست';
  end if;
  if new.status is distinct from old.status and not public.is_admin() then
    if auth.uid() = old.owner_id and old.status = 'agreed' and new.status = 'awaiting_pickup' then
      null;
    elsif auth.uid() = old.driver_id and old.status = 'awaiting_pickup' and new.status = 'in_transit' then
      null;
    elsif auth.uid() = old.driver_id and old.status = 'in_transit' and new.status = 'delivered' then
      null;
    else
      raise exception 'این تغییر وضعیت مجاز نیست';
    end if;
  end if;
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.guard_report_insert()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.reporter_id <> auth.uid() or new.status <> 'open' or new.resolved_at is not null or new.resolved_by is not null then
    raise exception 'گزارش نامعتبر است';
  end if;
  return new;
end;
$$;

create or replace function public.guard_report_update()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'فقط مدیر می‌تواند گزارش را تغییر دهد';
  end if;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before update on public.profiles for each row execute procedure public.guard_profile_update();
drop trigger if exists loads_guard on public.loads;
create trigger loads_guard before update on public.loads for each row execute procedure public.guard_load_update();
drop trigger if exists loads_touch on public.loads;
create trigger loads_touch before update on public.loads for each row execute procedure public.touch_updated_at();
drop trigger if exists private_details_touch on public.load_private_details;
create trigger private_details_touch before update on public.load_private_details for each row execute procedure public.touch_updated_at();
drop trigger if exists offers_touch on public.freight_offers;
create trigger offers_touch before update on public.freight_offers for each row execute procedure public.touch_updated_at();
drop trigger if exists shipments_guard on public.shipments;
create trigger shipments_guard before update on public.shipments for each row execute procedure public.guard_shipment_update();
drop trigger if exists reports_guard_insert on public.reports;
create trigger reports_guard_insert before insert on public.reports for each row execute procedure public.guard_report_insert();
drop trigger if exists reports_guard_update on public.reports;
create trigger reports_guard_update before update on public.reports for each row execute procedure public.guard_report_update();
