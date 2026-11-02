-- بارینو | شمای PostgreSQL و سیاست‌های RLS برای Supabase
-- این فایل را در SQL Editor پروژه Supabase، با یک حساب مالک پروژه، یک‌بار اجرا کنید.
-- هرگز service_role key را در مرورگر یا GitHub قرار ندهید.

create extension if not exists pgcrypto;

-- نقش مدیر عمداً در این enum یا جدول profiles قرار ندارد.
do $$ begin
  create type public.user_role as enum ('driver', 'cargo_owner');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.load_status as enum ('published', 'receiving_offers', 'agreed', 'awaiting_pickup', 'in_transit', 'delivered', 'cancelled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.offer_status as enum ('submitted', 'accepted', 'rejected', 'declined');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.report_status as enum ('open', 'resolved', 'dismissed');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.user_role not null default 'cargo_owner',
  display_name text check (char_length(display_name) between 2 and 100),
  phone text check (phone is null or phone ~ '^(\\+98|0098|0)?9[0-9]{9}$'),
  city text check (city is null or char_length(city) <= 80),
  truck_type text check (truck_type is null or char_length(truck_type) <= 80),
  truck_model text check (truck_model is null or char_length(truck_model) <= 100),
  plate_number text check (plate_number is null or char_length(plate_number) <= 30),
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- این جدول تنها محل تعیین مدیر است. برای کاربران عادی هیچ policy یا grant ندارد.
create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id)
);

create table if not exists public.loads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(btrim(title)) between 3 and 120),
  cargo_description text check (cargo_description is null or char_length(cargo_description) <= 1500),
  origin_city text not null check (char_length(btrim(origin_city)) between 2 and 80),
  destination_city text not null check (char_length(btrim(destination_city)) between 2 and 80),
  weight_value numeric(12,2) not null check (weight_value > 0),
  weight_unit text not null default 'تن' check (weight_unit in ('تن', 'کیلوگرم')),
  cargo_type text not null check (char_length(cargo_type) <= 80),
  required_truck_type text not null check (char_length(required_truck_type) <= 80),
  proposed_fare bigint not null check (proposed_fare > 0),
  loading_date date not null,
  notes text check (notes is null or char_length(notes) <= 2000),
  status public.load_status not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- نشانی دقیق هرگز در جدول قابل فهرست شدن loads نگهداری نمی‌شود.
create table if not exists public.load_private_details (
  load_id uuid primary key references public.loads(id) on delete cascade,
  pickup_address text not null check (char_length(btrim(pickup_address)) between 3 and 1000),
  delivery_address text not null check (char_length(btrim(delivery_address)) between 3 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.freight_offers (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null references public.loads(id) on delete cascade,
  driver_id uuid not null references public.profiles(id) on delete restrict,
  offered_fare bigint not null check (offered_fare > 0),
  note text check (note is null or char_length(note) <= 1000),
  status public.offer_status not null default 'submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint freight_offers_one_per_driver_load unique (load_id, driver_id)
);

create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  load_id uuid not null unique references public.loads(id) on delete restrict,
  offer_id uuid not null unique references public.freight_offers(id) on delete restrict,
  owner_id uuid not null references public.profiles(id) on delete restrict,
  driver_id uuid not null references public.profiles(id) on delete restrict,
  agreed_fare bigint not null check (agreed_fare > 0),
  status public.load_status not null default 'agreed' check (status in ('agreed', 'awaiting_pickup', 'in_transit', 'delivered', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shipment_status_history (
  id bigint generated always as identity primary key,
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  old_status public.load_status,
  new_status public.load_status not null,
  changed_by uuid references public.profiles(id) on delete set null,
  note text check (note is null or char_length(note) <= 1000),
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete restrict,
  subject text not null check (char_length(btrim(subject)) between 3 and 140),
  description text not null check (char_length(btrim(description)) between 3 and 2000),
  target_id uuid,
  status public.report_status not null default 'open',
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists loads_active_route_idx on public.loads (status, origin_city, destination_city, loading_date desc);
create index if not exists loads_owner_created_idx on public.loads (owner_id, created_at desc);
create index if not exists freight_offers_load_status_idx on public.freight_offers (load_id, status, created_at desc);
create index if not exists freight_offers_driver_created_idx on public.freight_offers (driver_id, created_at desc);
create index if not exists shipments_owner_status_idx on public.shipments (owner_id, status, created_at desc);
create index if not exists shipments_driver_status_idx on public.shipments (driver_id, status, created_at desc);
create index if not exists shipment_history_shipment_idx on public.shipment_status_history (shipment_id, created_at desc);
create index if not exists reports_status_created_idx on public.reports (status, created_at desc);

-- تابع بررسی مدیر: با SECURITY DEFINER به جدول خصوصی دسترسی دارد ولی فقط true/false برمی‌گرداند.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.app_admins a where a.user_id = auth.uid());
$$;

-- اعتبار تأیید ایمیل را مستقیماً از auth.users می‌خواند؛ به claim قابل جعل JWT تکیه نمی‌کند.
create or replace function public.is_confirmed_user()
returns boolean
language sql
stable
security definer
set search_path = auth, public
as $$
  select exists (
    select 1 from auth.users u
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;

-- یک حساب مسدودشده حتی با نشست معتبر نیز به داده‌ها و عملیات تجاری دسترسی ندارد.
create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.is_confirmed_user() and exists (
    select 1 from public.profiles p where p.id = auth.uid() and not p.is_blocked
  );
$$;

-- یک public profile امن برای مقایسه پیشنهادها؛ شماره، پلاک و آدرس در آن نیست.
create or replace view public.driver_public_profiles
with (security_invoker = false) as
  select id, display_name, truck_type, truck_model
  from public.profiles
  where role = 'driver' and is_blocked = false and public.is_active_user();

-- هنگام ثبت‌نام، نقش فقط راننده یا صاحب بار است. مدیر هرگز از user metadata ساخته نمی‌شود.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role)
  values (
    new.id,
    case when coalesce(new.raw_user_meta_data ->> 'signup_role', '') = 'driver'
      then 'driver'::public.user_role else 'cargo_owner'::public.user_role end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- مانع دست‌کاری role، مسدودسازی و روند وضعیت، حتی با درخواست HTTP مستقیم می‌شود.
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

-- همه جدول‌های حساس RLS دارند.
alter table public.profiles enable row level security;
alter table public.app_admins enable row level security;
alter table public.loads enable row level security;
alter table public.load_private_details enable row level security;
alter table public.freight_offers enable row level security;
alter table public.shipments enable row level security;
alter table public.shipment_status_history enable row level security;
alter table public.reports enable row level security;

-- اجرای دوباره فایل policyهای هم‌نام را پاک می‌کند.
drop policy if exists profiles_select_authorized on public.profiles;
create policy profiles_select_authorized on public.profiles for select to authenticated using (
  public.is_active_user() and (id = auth.uid() or public.is_admin() or exists (
    select 1 from public.shipments s
    where (s.owner_id = auth.uid() and s.driver_id = profiles.id)
       or (s.driver_id = auth.uid() and s.owner_id = profiles.id)
  ))
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
  using (public.is_active_user() and id = auth.uid() and not is_blocked)
  with check (public.is_active_user() and id = auth.uid());
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated
  using (public.is_active_user() and public.is_admin()) with check (public.is_active_user() and public.is_admin());

drop policy if exists loads_select_authorized on public.loads;
create policy loads_select_authorized on public.loads for select to authenticated using (
  public.is_active_user() and (
    public.is_admin()
    or owner_id = auth.uid()
    or (status in ('published', 'receiving_offers') and exists (select 1 from public.profiles p where p.id = auth.uid() and not p.is_blocked))
    or exists (select 1 from public.shipments s where s.load_id = loads.id and (s.owner_id = auth.uid() or s.driver_id = auth.uid()))
  )
);
drop policy if exists loads_update_owner on public.loads;
create policy loads_update_owner on public.loads for update to authenticated
  using (public.is_active_user() and owner_id = auth.uid() and status in ('published', 'receiving_offers'))
  with check (public.is_active_user() and owner_id = auth.uid());
drop policy if exists loads_update_admin on public.loads;
create policy loads_update_admin on public.loads for update to authenticated using (public.is_active_user() and public.is_admin()) with check (public.is_active_user() and public.is_admin());

drop policy if exists private_details_select_authorized on public.load_private_details;
create policy private_details_select_authorized on public.load_private_details for select to authenticated using (
  public.is_active_user() and (
    public.is_admin()
    or exists (select 1 from public.loads l where l.id = load_private_details.load_id and l.owner_id = auth.uid())
    or exists (select 1 from public.shipments s where s.load_id = load_private_details.load_id and (s.owner_id = auth.uid() or s.driver_id = auth.uid()))
  )
);

drop policy if exists offers_select_authorized on public.freight_offers;
create policy offers_select_authorized on public.freight_offers for select to authenticated using (
  public.is_active_user() and (public.is_admin() or driver_id = auth.uid() or exists (
    select 1 from public.loads l where l.id = freight_offers.load_id and l.owner_id = auth.uid()
  ))
);

drop policy if exists shipments_select_authorized on public.shipments;
create policy shipments_select_authorized on public.shipments for select to authenticated using (
  public.is_active_user() and (public.is_admin() or owner_id = auth.uid() or driver_id = auth.uid())
);

drop policy if exists shipment_history_select_authorized on public.shipment_status_history;
create policy shipment_history_select_authorized on public.shipment_status_history for select to authenticated using (
  public.is_active_user() and (public.is_admin() or exists (
    select 1 from public.shipments s where s.id = shipment_status_history.shipment_id
      and (s.owner_id = auth.uid() or s.driver_id = auth.uid())
  ))
);

drop policy if exists reports_select_authorized on public.reports;
create policy reports_select_authorized on public.reports for select to authenticated using (public.is_active_user() and (reporter_id = auth.uid() or public.is_admin()));
drop policy if exists reports_insert_self on public.reports;
create policy reports_insert_self on public.reports for insert to authenticated with check (
  public.is_active_user() and reporter_id = auth.uid() and status = 'open' and resolved_at is null and resolved_by is null
);
drop policy if exists reports_update_admin on public.reports;
create policy reports_update_admin on public.reports for update to authenticated using (public.is_active_user() and public.is_admin()) with check (public.is_active_user() and public.is_admin());

-- RPC اتمیک ثبت بار و نشانی خصوصی.
create or replace function public.create_load_with_private_details(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_weight numeric;
  v_fare bigint;
  v_loading date;
begin
  if auth.uid() is null then raise exception 'ورود به حساب الزامی است'; end if;
  if not public.is_active_user() then raise exception 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است'; end if;
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'cargo_owner' and not p.is_blocked) then
    raise exception 'فقط صاحب بار فعال می‌تواند بار ثبت کند';
  end if;
  if coalesce(length(btrim(p_payload->>'title')), 0) not between 3 and 120
     or coalesce(length(btrim(p_payload->>'origin_city')), 0) < 2
     or coalesce(length(btrim(p_payload->>'destination_city')), 0) < 2
     or coalesce(length(btrim(p_payload->>'pickup_address')), 0) < 3
     or coalesce(length(btrim(p_payload->>'delivery_address')), 0) < 3 then
    raise exception 'اطلاعات ضروری بار معتبر نیست';
  end if;
  v_weight := (p_payload->>'weight_value')::numeric;
  v_fare := (p_payload->>'proposed_fare')::bigint;
  v_loading := (p_payload->>'loading_date')::date;
  if v_weight <= 0 or v_fare <= 0 or v_loading < current_date then raise exception 'وزن، کرایه یا تاریخ بارگیری معتبر نیست'; end if;
  if p_payload->>'weight_unit' not in ('تن','کیلوگرم') then raise exception 'واحد وزن نامعتبر است'; end if;
  insert into public.loads (owner_id,title,cargo_description,origin_city,destination_city,weight_value,weight_unit,cargo_type,required_truck_type,proposed_fare,loading_date,notes)
  values (auth.uid(), btrim(p_payload->>'title'), nullif(btrim(p_payload->>'cargo_description'),''), btrim(p_payload->>'origin_city'), btrim(p_payload->>'destination_city'), v_weight, p_payload->>'weight_unit', btrim(p_payload->>'cargo_type'), btrim(p_payload->>'required_truck_type'), v_fare, v_loading, nullif(btrim(p_payload->>'notes'),''))
  returning id into v_id;
  insert into public.load_private_details (load_id,pickup_address,delivery_address)
  values (v_id,btrim(p_payload->>'pickup_address'),btrim(p_payload->>'delivery_address'));
  return v_id;
end;
$$;

-- RPC اتمیک پیشنهاد؛ در سطح دیتابیس نقش، بازبودن بار و تکراری نبودن کنترل می‌شود.
create or replace function public.submit_freight_offer(p_load_id uuid, p_offered_fare bigint, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_load public.loads%rowtype;
  v_offer_id uuid;
begin
  if auth.uid() is null then raise exception 'ورود به حساب الزامی است'; end if;
  if not public.is_active_user() then raise exception 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است'; end if;
  if p_offered_fare is null or p_offered_fare <= 0 or coalesce(length(p_note),0) > 1000 then raise exception 'پیشنهاد معتبر نیست'; end if;
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'driver' and not p.is_blocked and p.display_name is not null and p.phone is not null and p.truck_type is not null) then
    raise exception 'پروفایل راننده باید کامل و فعال باشد';
  end if;
  select * into v_load from public.loads where id = p_load_id for update;
  if not found or v_load.status not in ('published','receiving_offers') then raise exception 'این بار برای پیشنهاد باز نیست'; end if;
  if v_load.owner_id = auth.uid() then raise exception 'نمی‌توانید برای بار خود پیشنهاد بدهید'; end if;
  insert into public.freight_offers (load_id,driver_id,offered_fare,note)
  values (p_load_id,auth.uid(),p_offered_fare,nullif(btrim(p_note),'')) returning id into v_offer_id;
  if v_load.status = 'published' then
    perform set_config('app.barino_transition','offer',true);
    update public.loads set status = 'receiving_offers' where id = p_load_id;
  end if;
  return v_offer_id;
exception when unique_violation then
  raise exception 'برای این بار قبلاً پیشنهاد ثبت کرده‌اید';
end;
$$;

-- قبول پیشنهاد در یک تراکنش: قفل بار، سفارش یکتا، مختومه‌کردن سایر پیشنهادها و تاریخچه.
create or replace function public.accept_freight_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer public.freight_offers%rowtype;
  v_load public.loads%rowtype;
  v_shipment_id uuid;
begin
  if auth.uid() is null then raise exception 'ورود به حساب الزامی است'; end if;
  if not public.is_active_user() then raise exception 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است'; end if;
  select * into v_offer from public.freight_offers where id = p_offer_id for update;
  if not found or v_offer.status <> 'submitted' then raise exception 'این پیشنهاد قابل پذیرش نیست'; end if;
  select * into v_load from public.loads where id = v_offer.load_id for update;
  if not found or v_load.owner_id <> auth.uid() then raise exception 'فقط صاحب بار می‌تواند پیشنهاد را بپذیرد'; end if;
  if v_load.status not in ('published','receiving_offers') then raise exception 'بار دیگر برای توافق باز نیست'; end if;
  if exists (select 1 from public.profiles p where p.id in (auth.uid(),v_offer.driver_id) and p.is_blocked) then raise exception 'یکی از طرفین حساب فعال ندارد'; end if;
  perform set_config('app.barino_transition','accept',true);
  update public.loads set status = 'agreed' where id = v_load.id;
  update public.freight_offers set status = 'accepted' where id = v_offer.id;
  update public.freight_offers set status = 'declined' where load_id = v_load.id and id <> v_offer.id and status = 'submitted';
  insert into public.shipments (load_id,offer_id,owner_id,driver_id,agreed_fare,status)
  values (v_load.id,v_offer.id,v_load.owner_id,v_offer.driver_id,v_offer.offered_fare,'agreed') returning id into v_shipment_id;
  insert into public.shipment_status_history (shipment_id,old_status,new_status,changed_by,note)
  values (v_shipment_id,null,'agreed',auth.uid(),'پیشنهاد کرایه پذیرفته شد');
  return v_shipment_id;
end;
$$;

create or replace function public.change_shipment_status(p_shipment_id uuid, p_new_status public.load_status, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_shipment public.shipments%rowtype;
begin
  if auth.uid() is null then raise exception 'ورود به حساب الزامی است'; end if;
  if not public.is_active_user() then raise exception 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است'; end if;
  if coalesce(length(p_note),0) > 1000 then raise exception 'توضیح وضعیت طولانی است'; end if;
  select * into v_shipment from public.shipments where id = p_shipment_id for update;
  if not found then raise exception 'سفارش پیدا نشد'; end if;
  -- trigger نیز همین قواعد را کنترل می‌کند؛ این شرط برای پیام شفاف‌تر است.
  if not ((auth.uid() = v_shipment.owner_id and v_shipment.status = 'agreed' and p_new_status = 'awaiting_pickup')
      or (auth.uid() = v_shipment.driver_id and v_shipment.status = 'awaiting_pickup' and p_new_status = 'in_transit')
      or (auth.uid() = v_shipment.driver_id and v_shipment.status = 'in_transit' and p_new_status = 'delivered')) then
    raise exception 'این تغییر وضعیت برای نقش یا مرحله فعلی مجاز نیست';
  end if;
  update public.shipments set status = p_new_status where id = p_shipment_id;
  perform set_config('app.barino_transition','shipment',true);
  update public.loads set status = p_new_status where id = v_shipment.load_id;
  insert into public.shipment_status_history (shipment_id,old_status,new_status,changed_by,note)
  values (p_shipment_id,v_shipment.status,p_new_status,auth.uid(),nullif(btrim(p_note),''));
end;
$$;

-- RLS روی loads تغییر وضعیت shipment را برای راننده لازم ندارد؛ این RPC با definer کار می‌کند.
-- برای تغییر status بار از توافق تا تحویل، context داخلی تابع را مشخص می‌کنیم.
create or replace function public.sync_load_status_from_shipment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$ begin return new; end; $$;

-- ویرایش اتمیک بار و نشانی خصوصی تا قبل از توافق.
create or replace function public.update_load_with_private_details(p_load_id uuid, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_load public.loads%rowtype; v_weight numeric; v_fare bigint; v_date date;
begin
  if auth.uid() is null then raise exception 'ورود به حساب الزامی است'; end if;
  if not public.is_active_user() then raise exception 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است'; end if;
  select * into v_load from public.loads where id = p_load_id for update;
  if not found or v_load.owner_id <> auth.uid() or v_load.status not in ('published','receiving_offers') then raise exception 'ویرایش این بار مجاز نیست'; end if;
  v_weight := (p_payload->>'weight_value')::numeric; v_fare := (p_payload->>'proposed_fare')::bigint; v_date := (p_payload->>'loading_date')::date;
  if coalesce(length(btrim(p_payload->>'title')),0) not between 3 and 120 or coalesce(length(btrim(p_payload->>'origin_city')),0)<2 or coalesce(length(btrim(p_payload->>'destination_city')),0)<2 or coalesce(length(btrim(p_payload->>'pickup_address')),0)<3 or coalesce(length(btrim(p_payload->>'delivery_address')),0)<3 or v_weight<=0 or v_fare<=0 or v_date<current_date then raise exception 'اطلاعات بار معتبر نیست'; end if;
  update public.loads set title=btrim(p_payload->>'title'),cargo_description=nullif(btrim(p_payload->>'cargo_description'),''),origin_city=btrim(p_payload->>'origin_city'),destination_city=btrim(p_payload->>'destination_city'),weight_value=v_weight,weight_unit=p_payload->>'weight_unit',cargo_type=btrim(p_payload->>'cargo_type'),required_truck_type=btrim(p_payload->>'required_truck_type'),proposed_fare=v_fare,loading_date=v_date,notes=nullif(btrim(p_payload->>'notes'),'') where id=p_load_id;
  update public.load_private_details set pickup_address=btrim(p_payload->>'pickup_address'),delivery_address=btrim(p_payload->>'delivery_address') where load_id=p_load_id;
end;
$$;

-- فقط طرف‌های سفارش می‌توانند خروجی شامل شماره تماس و نشانی دقیق را دریافت کنند.
create or replace function public.get_shipment_private_details(p_shipment_id uuid)
returns table (counterparty_name text, counterparty_phone text, pickup_address text, delivery_address text)
language plpgsql
security definer
set search_path = public
as $$
declare v_shipment public.shipments%rowtype; v_other uuid;
begin
  if not public.is_active_user() then raise exception 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است'; end if;
  select * into v_shipment from public.shipments where id = p_shipment_id;
  if not found or not (public.is_admin() or auth.uid() = v_shipment.owner_id or auth.uid() = v_shipment.driver_id) then raise exception 'دسترسی به اطلاعات خصوصی مجاز نیست'; end if;
  v_other := case when auth.uid() = v_shipment.owner_id then v_shipment.driver_id else v_shipment.owner_id end;
  return query select p.display_name, p.phone, d.pickup_address, d.delivery_address
    from public.load_private_details d join public.profiles p on p.id = v_other
    where d.load_id = v_shipment.load_id;
end;
$$;

-- سطح دسترسی SQL. کلاینت فقط عملیات لازم را دارد؛ نوشتن حساس فقط از RPCهاست.
-- پیش‌فرض PostgreSQL برای EXECUTE روی functionها public است؛ آن را صریحاً می‌بندیم.
revoke all on function public.is_admin() from public, anon;
revoke all on function public.is_confirmed_user() from public, anon;
revoke all on function public.is_active_user() from public, anon;
revoke all on function public.create_load_with_private_details(jsonb) from public, anon;
revoke all on function public.update_load_with_private_details(uuid,jsonb) from public, anon;
revoke all on function public.submit_freight_offer(uuid,bigint,text) from public, anon;
revoke all on function public.accept_freight_offer(uuid) from public, anon;
revoke all on function public.change_shipment_status(uuid,public.load_status,text) from public, anon;
revoke all on function public.get_shipment_private_details(uuid) from public, anon;
revoke all on table public.profiles, public.loads, public.load_private_details, public.freight_offers, public.shipments, public.shipment_status_history, public.reports from public, anon;
revoke all on public.driver_public_profiles from public, anon;
revoke all on table public.app_admins from public, anon, authenticated;

grant usage on schema public to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.driver_public_profiles to authenticated;
grant select, update on public.loads to authenticated;
grant select on public.load_private_details to authenticated;
grant select on public.freight_offers to authenticated;
grant select on public.shipments to authenticated;
grant select on public.shipment_status_history to authenticated;
grant select, insert, update on public.reports to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_confirmed_user() to authenticated;
grant execute on function public.is_active_user() to authenticated;
grant execute on function public.create_load_with_private_details(jsonb) to authenticated;
grant execute on function public.update_load_with_private_details(uuid,jsonb) to authenticated;
grant execute on function public.submit_freight_offer(uuid,bigint,text) to authenticated;
grant execute on function public.accept_freight_offer(uuid) to authenticated;
grant execute on function public.change_shipment_status(uuid,public.load_status,text) to authenticated;
grant execute on function public.get_shipment_private_details(uuid) to authenticated;

-- ایجاد اولین مدیر (فقط پس از آنکه کاربر از طریق Auth ثبت‌نام کرد، در SQL Editor مالک اجرا شود):
-- insert into public.app_admins (user_id) values ('UUID-کاربر-مدیر');
-- هیچ راهی در فرانت‌اند برای اجرای دستور بالا وجود ندارد.

-- چک‌های دستی پیشنهادی RLS (با دو حساب تست جداگانه اجرا کنید):
-- 1) راننده A نباید بتواند select از profiles برای کاربر نامرتبط یا load_private_details یک بار باز انجام دهد.
-- 2) صاحب بار B نباید بتواند select/update پیشنهاد یا بار صاحب بار C را انجام دهد.
-- 3) راننده نباید بتواند update مستقیم loads یا insert مستقیم freight_offers انجام دهد.
-- 4) هم‌زمان accept_freight_offer را برای دو پیشنهاد یک بار اجرا کنید: تنها یکی باید سفارش بسازد.
-- 5) کاربر عادی نباید بتواند select از app_admins یا با update profiles نقش مدیر بگیرد.

-- Admin console additive migration: see supabase/migrations/20261102100000_admin_console.sql.
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
-- Barino validation and abuse-control hardening.
-- Additive only: existing rows are retained while all new/updated writes are validated.

-- The old pattern had two backslashes before +98 and could reject a valid +989… number.
-- Keep exactly these three explicit Iranian mobile formats for future writes:
-- 09xxxxxxxxx, +989xxxxxxxxx, 00989xxxxxxxxx.
alter table public.profiles drop constraint if exists profiles_phone_check;
alter table public.profiles drop constraint if exists profiles_phone_iran_format_check;
alter table public.profiles
  add constraint profiles_phone_iran_format_check
  check (phone is null or phone ~ '^(09[0-9]{9}|[+]989[0-9]{9}|00989[0-9]{9})$') not valid;

-- Store a single ASCII representation. This mirrors the browser: Persian/Arabic digits and
-- visual whitespace/hyphens are normalized, while every other character remains invalid.
create or replace function public.normalize_profile_phone()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  if new.phone is not null then
    new.phone := regexp_replace(
      translate(new.phone, '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'),
      '[[:space:]-]', '', 'g'
    );
  end if;
  return new;
end;
$$;
revoke all on function public.normalize_profile_phone() from public, anon, authenticated;
drop trigger if exists profiles_phone_normalize on public.profiles;
create trigger profiles_phone_normalize
  before insert or update of phone on public.profiles
  for each row execute function public.normalize_profile_phone();

-- These constraints do not scan or delete historic records, but reject blank or malformed
-- content on every new insert/update. The RPCs below use the same boundaries.
alter table public.profiles drop constraint if exists profiles_display_name_trimmed_check;
alter table public.profiles
  add constraint profiles_display_name_trimmed_check
  check (display_name is null or char_length(btrim(display_name)) between 2 and 100) not valid;
alter table public.loads drop constraint if exists loads_cargo_type_trimmed_check;
alter table public.loads
  add constraint loads_cargo_type_trimmed_check
  check (char_length(btrim(cargo_type)) between 2 and 80) not valid;
alter table public.loads drop constraint if exists loads_required_truck_type_trimmed_check;
alter table public.loads
  add constraint loads_required_truck_type_trimmed_check
  check (char_length(btrim(required_truck_type)) between 2 and 80) not valid;

create index if not exists reports_reporter_created_idx
  on public.reports (reporter_id, created_at desc);

-- Harden every SECURITY DEFINER business function with an explicit safe search path.
create or replace function public.is_confirmed_user()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, auth, public
as $$
  select exists (
    select 1 from auth.users u
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select public.is_confirmed_user() and exists (
    select 1 from public.profiles p where p.id = auth.uid() and not p.is_blocked
  );
$$;

-- A report is the only browser-direct insert. Force server timestamps and serialize the
-- reporter's recent writes so parallel requests cannot bypass the per-account limit.
create or replace function public.guard_report_insert()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if auth.uid() is null or not public.is_active_user()
     or new.reporter_id is distinct from auth.uid()
     or new.status <> 'open'
     or new.resolved_at is not null
     or new.resolved_by is not null then
    raise exception using errcode = '42501', message = 'گزارش مجاز نیست';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.reporter_id::text, 2026110213));
  if (
    select count(*)
    from public.reports r
    where r.reporter_id = new.reporter_id
      and r.created_at >= clock_timestamp() - interval '15 minutes'
  ) >= 3 then
    raise exception using errcode = 'P0001', message = 'برای جلوگیری از سوءاستفاده، در هر ۱۵ دقیقه حداکثر سه گزارش مجاز است';
  end if;

  new.created_at := clock_timestamp();
  new.updated_at := new.created_at;
  return new;
end;
$$;
revoke all on function public.guard_report_insert() from public, anon, authenticated;

-- Registration and edit payloads are treated as untrusted JSON. Validate every persisted
-- value before casting, avoid database parser errors, and ignore no unexpected keys.
create or replace function public.create_load_with_private_details(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_id uuid;
  v_weight numeric;
  v_fare bigint;
  v_loading date;
  v_weight_text text;
  v_fare_text text;
  v_date_text text;
  v_title text;
  v_origin text;
  v_destination text;
  v_pickup text;
  v_delivery text;
  v_cargo_type text;
  v_truck_type text;
  v_cargo_description text;
  v_notes text;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'cargo_owner' and not p.is_blocked
  ) then
    raise exception using errcode = '42501', message = 'فقط صاحب بار فعال می‌تواند بار ثبت کند';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'اطلاعات بار نامعتبر است';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(p_payload) as payload_key(key)
    where key not in (
      'title', 'cargo_description', 'cargo_type', 'required_truck_type', 'weight_value',
      'weight_unit', 'origin_city', 'destination_city', 'pickup_address', 'delivery_address',
      'loading_date', 'proposed_fare', 'notes'
    )
  ) then
    raise exception using errcode = '22023', message = 'اطلاعات ارسالی بار نامعتبر است';
  end if;

  v_title := btrim(coalesce(p_payload ->> 'title', ''));
  v_origin := btrim(coalesce(p_payload ->> 'origin_city', ''));
  v_destination := btrim(coalesce(p_payload ->> 'destination_city', ''));
  v_pickup := btrim(coalesce(p_payload ->> 'pickup_address', ''));
  v_delivery := btrim(coalesce(p_payload ->> 'delivery_address', ''));
  v_cargo_type := btrim(coalesce(p_payload ->> 'cargo_type', ''));
  v_truck_type := btrim(coalesce(p_payload ->> 'required_truck_type', ''));
  v_cargo_description := nullif(btrim(coalesce(p_payload ->> 'cargo_description', '')), '');
  v_notes := nullif(btrim(coalesce(p_payload ->> 'notes', '')), '');
  if char_length(v_title) not between 3 and 120
     or char_length(v_origin) not between 2 and 80
     or char_length(v_destination) not between 2 and 80
     or char_length(v_pickup) not between 3 and 1000
     or char_length(v_delivery) not between 3 and 1000
     or char_length(v_cargo_type) not between 2 and 80
     or char_length(v_truck_type) not between 2 and 80
     or coalesce(char_length(v_cargo_description), 0) > 1500
     or coalesce(char_length(v_notes), 0) > 2000 then
    raise exception using errcode = '22023', message = 'اطلاعات بار معتبر نیست';
  end if;
  if coalesce(p_payload ->> 'weight_unit', '') not in ('تن', 'کیلوگرم') then
    raise exception using errcode = '22023', message = 'واحد وزن نامعتبر است';
  end if;

  v_weight_text := btrim(coalesce(p_payload ->> 'weight_value', ''));
  v_fare_text := btrim(coalesce(p_payload ->> 'proposed_fare', ''));
  v_date_text := btrim(coalesce(p_payload ->> 'loading_date', ''));
  if v_weight_text !~ '^[0-9]+([.][0-9]{1,2})?$'
     or v_fare_text !~ '^[0-9]{1,18}$'
     or v_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = '22023', message = 'وزن، کرایه یا تاریخ بارگیری معتبر نیست';
  end if;
  begin
    v_weight := v_weight_text::numeric;
    v_fare := v_fare_text::bigint;
    v_loading := v_date_text::date;
  exception when others then
    raise exception using errcode = '22023', message = 'وزن، کرایه یا تاریخ بارگیری معتبر نیست';
  end;
  if v_weight <= 0 or v_weight > 9999999999.99 or v_fare <= 0 or v_loading < current_date then
    raise exception using errcode = '22023', message = 'وزن، کرایه یا تاریخ بارگیری معتبر نیست';
  end if;

  insert into public.loads (
    owner_id, title, cargo_description, origin_city, destination_city, weight_value, weight_unit,
    cargo_type, required_truck_type, proposed_fare, loading_date, notes
  ) values (
    auth.uid(), v_title, v_cargo_description, v_origin, v_destination, v_weight,
    p_payload ->> 'weight_unit', v_cargo_type, v_truck_type, v_fare, v_loading, v_notes
  ) returning id into v_id;
  insert into public.load_private_details (load_id, pickup_address, delivery_address)
  values (v_id, v_pickup, v_delivery);
  return v_id;
end;
$$;

create or replace function public.update_load_with_private_details(p_load_id uuid, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_load public.loads%rowtype;
  v_weight numeric;
  v_fare bigint;
  v_loading date;
  v_weight_text text;
  v_fare_text text;
  v_date_text text;
  v_title text;
  v_origin text;
  v_destination text;
  v_pickup text;
  v_delivery text;
  v_cargo_type text;
  v_truck_type text;
  v_cargo_description text;
  v_notes text;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'اطلاعات بار نامعتبر است';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(p_payload) as payload_key(key)
    where key not in (
      'title', 'cargo_description', 'cargo_type', 'required_truck_type', 'weight_value',
      'weight_unit', 'origin_city', 'destination_city', 'pickup_address', 'delivery_address',
      'loading_date', 'proposed_fare', 'notes'
    )
  ) then
    raise exception using errcode = '22023', message = 'اطلاعات ارسالی بار نامعتبر است';
  end if;

  select * into v_load from public.loads where id = p_load_id for update;
  if not found or v_load.owner_id <> auth.uid() or v_load.status not in ('published', 'receiving_offers') then
    raise exception using errcode = '42501', message = 'ویرایش این بار مجاز نیست';
  end if;

  v_title := btrim(coalesce(p_payload ->> 'title', ''));
  v_origin := btrim(coalesce(p_payload ->> 'origin_city', ''));
  v_destination := btrim(coalesce(p_payload ->> 'destination_city', ''));
  v_pickup := btrim(coalesce(p_payload ->> 'pickup_address', ''));
  v_delivery := btrim(coalesce(p_payload ->> 'delivery_address', ''));
  v_cargo_type := btrim(coalesce(p_payload ->> 'cargo_type', ''));
  v_truck_type := btrim(coalesce(p_payload ->> 'required_truck_type', ''));
  v_cargo_description := nullif(btrim(coalesce(p_payload ->> 'cargo_description', '')), '');
  v_notes := nullif(btrim(coalesce(p_payload ->> 'notes', '')), '');
  if char_length(v_title) not between 3 and 120
     or char_length(v_origin) not between 2 and 80
     or char_length(v_destination) not between 2 and 80
     or char_length(v_pickup) not between 3 and 1000
     or char_length(v_delivery) not between 3 and 1000
     or char_length(v_cargo_type) not between 2 and 80
     or char_length(v_truck_type) not between 2 and 80
     or coalesce(char_length(v_cargo_description), 0) > 1500
     or coalesce(char_length(v_notes), 0) > 2000 then
    raise exception using errcode = '22023', message = 'اطلاعات بار معتبر نیست';
  end if;
  if coalesce(p_payload ->> 'weight_unit', '') not in ('تن', 'کیلوگرم') then
    raise exception using errcode = '22023', message = 'واحد وزن نامعتبر است';
  end if;

  v_weight_text := btrim(coalesce(p_payload ->> 'weight_value', ''));
  v_fare_text := btrim(coalesce(p_payload ->> 'proposed_fare', ''));
  v_date_text := btrim(coalesce(p_payload ->> 'loading_date', ''));
  if v_weight_text !~ '^[0-9]+([.][0-9]{1,2})?$'
     or v_fare_text !~ '^[0-9]{1,18}$'
     or v_date_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = '22023', message = 'وزن، کرایه یا تاریخ بارگیری معتبر نیست';
  end if;
  begin
    v_weight := v_weight_text::numeric;
    v_fare := v_fare_text::bigint;
    v_loading := v_date_text::date;
  exception when others then
    raise exception using errcode = '22023', message = 'وزن، کرایه یا تاریخ بارگیری معتبر نیست';
  end;
  if v_weight <= 0 or v_weight > 9999999999.99 or v_fare <= 0 or v_loading < current_date then
    raise exception using errcode = '22023', message = 'وزن، کرایه یا تاریخ بارگیری معتبر نیست';
  end if;

  update public.loads
  set title = v_title,
      cargo_description = v_cargo_description,
      origin_city = v_origin,
      destination_city = v_destination,
      weight_value = v_weight,
      weight_unit = p_payload ->> 'weight_unit',
      cargo_type = v_cargo_type,
      required_truck_type = v_truck_type,
      proposed_fare = v_fare,
      loading_date = v_loading,
      notes = v_notes
  where id = p_load_id;
  update public.load_private_details
  set pickup_address = v_pickup,
      delivery_address = v_delivery
  where load_id = p_load_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'جزئیات خصوصی بار پیدا نشد';
  end if;
end;
$$;

create or replace function public.submit_freight_offer(p_load_id uuid, p_offered_fare bigint, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_load public.loads%rowtype;
  v_offer_id uuid;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if p_load_id is null or p_offered_fare is null or p_offered_fare <= 0 or coalesce(char_length(btrim(p_note)), 0) > 1000 then
    raise exception using errcode = '22023', message = 'پیشنهاد معتبر نیست';
  end if;
  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'driver' and not p.is_blocked
      and p.display_name is not null and p.phone is not null and p.truck_type is not null
  ) then
    raise exception using errcode = '42501', message = 'پروفایل راننده باید کامل و فعال باشد';
  end if;
  select * into v_load from public.loads where id = p_load_id for update;
  if not found or v_load.status not in ('published', 'receiving_offers') then
    raise exception using errcode = '22023', message = 'این بار برای پیشنهاد باز نیست';
  end if;
  if v_load.owner_id = auth.uid() then
    raise exception using errcode = '22023', message = 'نمی‌توانید برای بار خود پیشنهاد بدهید';
  end if;
  insert into public.freight_offers (load_id, driver_id, offered_fare, note)
  values (p_load_id, auth.uid(), p_offered_fare, nullif(btrim(p_note), ''))
  returning id into v_offer_id;
  if v_load.status = 'published' then
    perform set_config('app.barino_transition', 'offer', true);
    update public.loads set status = 'receiving_offers' where id = p_load_id;
  end if;
  return v_offer_id;
exception when unique_violation then
  raise exception using errcode = '23505', message = 'برای این بار قبلاً پیشنهاد ثبت کرده‌اید';
end;
$$;

create or replace function public.accept_freight_offer(p_offer_id uuid)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_offer public.freight_offers%rowtype;
  v_load public.loads%rowtype;
  v_load_id uuid;
  v_shipment_id uuid;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if p_offer_id is null then
    raise exception using errcode = '22023', message = 'پیشنهاد معتبر نیست';
  end if;
  -- Lock the load before an offer. submit/cancel/admin cancellation all lock in this same
  -- order, which avoids a deadlock between an acceptance and a concurrent cancellation.
  select o.load_id into v_load_id from public.freight_offers o where o.id = p_offer_id;
  if not found then
    raise exception using errcode = '22023', message = 'این پیشنهاد قابل پذیرش نیست';
  end if;
  select * into v_load from public.loads where id = v_load_id for update;
  if not found or v_load.owner_id <> auth.uid() then
    raise exception using errcode = '42501', message = 'فقط صاحب بار می‌تواند پیشنهاد را بپذیرد';
  end if;
  if v_load.status not in ('published', 'receiving_offers') then
    raise exception using errcode = '22023', message = 'بار دیگر برای توافق باز نیست';
  end if;
  select * into v_offer from public.freight_offers where id = p_offer_id for update;
  if not found or v_offer.status <> 'submitted' or v_offer.load_id <> v_load.id then
    raise exception using errcode = '22023', message = 'این پیشنهاد قابل پذیرش نیست';
  end if;
  if exists (
    select 1 from public.profiles p
    where p.id in (auth.uid(), v_offer.driver_id) and p.is_blocked
  ) then
    raise exception using errcode = '42501', message = 'یکی از طرفین حساب فعال ندارد';
  end if;
  perform set_config('app.barino_transition', 'accept', true);
  update public.loads set status = 'agreed' where id = v_load.id;
  update public.freight_offers set status = 'accepted' where id = v_offer.id;
  update public.freight_offers set status = 'declined'
  where load_id = v_load.id and id <> v_offer.id and status = 'submitted';
  insert into public.shipments (load_id, offer_id, owner_id, driver_id, agreed_fare, status)
  values (v_load.id, v_offer.id, v_load.owner_id, v_offer.driver_id, v_offer.offered_fare, 'agreed')
  returning id into v_shipment_id;
  insert into public.shipment_status_history (shipment_id, old_status, new_status, changed_by, note)
  values (v_shipment_id, null, 'agreed', auth.uid(), 'پیشنهاد کرایه پذیرفته شد');
  return v_shipment_id;
exception when unique_violation then
  raise exception using errcode = '23505', message = 'برای این بار قبلاً سفارش ایجاد شده است';
end;
$$;

create or replace function public.change_shipment_status(p_shipment_id uuid, p_new_status public.load_status, p_note text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_shipment public.shipments%rowtype;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if p_shipment_id is null or p_new_status is null or coalesce(char_length(btrim(p_note)), 0) > 1000 then
    raise exception using errcode = '22023', message = 'تغییر وضعیت سفارش معتبر نیست';
  end if;
  select * into v_shipment from public.shipments where id = p_shipment_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'سفارش پیدا نشد';
  end if;
  if not (
    (auth.uid() = v_shipment.owner_id and v_shipment.status = 'agreed' and p_new_status = 'awaiting_pickup')
    or (auth.uid() = v_shipment.driver_id and v_shipment.status = 'awaiting_pickup' and p_new_status = 'in_transit')
    or (auth.uid() = v_shipment.driver_id and v_shipment.status = 'in_transit' and p_new_status = 'delivered')
  ) then
    raise exception using errcode = '42501', message = 'این تغییر وضعیت برای نقش یا مرحله فعلی مجاز نیست';
  end if;
  update public.shipments set status = p_new_status where id = p_shipment_id;
  perform set_config('app.barino_transition', 'shipment', true);
  update public.loads set status = p_new_status where id = v_shipment.load_id;
  insert into public.shipment_status_history (shipment_id, old_status, new_status, changed_by, note)
  values (p_shipment_id, v_shipment.status, p_new_status, auth.uid(), nullif(btrim(p_note), ''));
end;
$$;

create or replace function public.get_shipment_private_details(p_shipment_id uuid)
returns table (counterparty_name text, counterparty_phone text, pickup_address text, delivery_address text)
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_shipment public.shipments%rowtype;
  v_other uuid;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if p_shipment_id is null then
    raise exception using errcode = '22023', message = 'سفارش نامعتبر است';
  end if;
  select * into v_shipment from public.shipments where id = p_shipment_id;
  if not found or not (
    public.is_admin() or auth.uid() = v_shipment.owner_id or auth.uid() = v_shipment.driver_id
  ) then
    raise exception using errcode = '42501', message = 'دسترسی به اطلاعات خصوصی مجاز نیست';
  end if;
  v_other := case when auth.uid() = v_shipment.owner_id then v_shipment.driver_id else v_shipment.owner_id end;
  return query
    select p.display_name, p.phone, d.pickup_address, d.delivery_address
    from public.load_private_details d
    join public.profiles p on p.id = v_other
    where d.load_id = v_shipment.load_id;
end;
$$;

-- Cancelling a load also closes its submitted offers under the same row lock.  The browser
-- must not be able to update loads directly, so a cancellation cannot race an acceptance and
-- leave open offers behind.
create or replace function public.cancel_load(p_load_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_load public.loads%rowtype;
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception using errcode = '42501', message = 'حساب شما فعال نیست یا ایمیل آن تأیید نشده است';
  end if;
  if p_load_id is null then
    raise exception using errcode = '22023', message = 'بار نامعتبر است';
  end if;
  select * into v_load from public.loads where id = p_load_id for update;
  if not found or v_load.owner_id <> auth.uid() or v_load.status not in ('published', 'receiving_offers') then
    raise exception using errcode = '42501', message = 'لغو این بار مجاز نیست';
  end if;
  update public.loads set status = 'cancelled' where id = p_load_id;
  update public.freight_offers
  set status = 'declined'
  where load_id = p_load_id and status = 'submitted';
end;
$$;

-- All load writes now use guarded RPCs (including cancellation); RLS alone is not a
-- transactional business-workflow boundary.  The administrative RPCs are SECURITY DEFINER too.
drop policy if exists loads_update_owner on public.loads;
drop policy if exists loads_update_admin on public.loads;
revoke update on table public.loads from authenticated;

-- Reassert least-privilege function access after replacements.
revoke all on function public.is_confirmed_user() from public, anon;
revoke all on function public.is_active_user() from public, anon;
revoke all on function public.create_load_with_private_details(jsonb) from public, anon;
revoke all on function public.update_load_with_private_details(uuid, jsonb) from public, anon;
revoke all on function public.submit_freight_offer(uuid, bigint, text) from public, anon;
revoke all on function public.accept_freight_offer(uuid) from public, anon;
revoke all on function public.change_shipment_status(uuid, public.load_status, text) from public, anon;
revoke all on function public.get_shipment_private_details(uuid) from public, anon;
revoke all on function public.cancel_load(uuid) from public, anon;
grant execute on function public.is_confirmed_user() to authenticated;
grant execute on function public.is_active_user() to authenticated;
grant execute on function public.create_load_with_private_details(jsonb) to authenticated;
grant execute on function public.update_load_with_private_details(uuid, jsonb) to authenticated;
grant execute on function public.submit_freight_offer(uuid, bigint, text) to authenticated;
grant execute on function public.accept_freight_offer(uuid) to authenticated;
grant execute on function public.change_shipment_status(uuid, public.load_status, text) to authenticated;
grant execute on function public.get_shipment_private_details(uuid) to authenticated;
grant execute on function public.cancel_load(uuid) to authenticated;
