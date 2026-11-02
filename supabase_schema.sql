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


-- امکانات پنل مدیریت امن. برای دیتابیس موجود، migration متناظر را اجرا کنید.
-- Barino secure administration console.
-- This migration is intentionally manual-only through the existing schema workflow.
-- It adds server-checked admin read/actions; the browser never receives a service_role key.

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null references public.profiles(id) on delete restrict,
  action text not null check (action in ('user_blocked', 'user_unblocked', 'load_status_changed')),
  target_user_id uuid references public.profiles(id) on delete set null,
  target_load_id uuid references public.loads(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_idx on public.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_target_user_idx on public.admin_audit_log (target_user_id, created_at desc);
create index if not exists admin_audit_log_target_load_idx on public.admin_audit_log (target_load_id, created_at desc);

alter table public.admin_audit_log enable row level security;
revoke all on table public.admin_audit_log from public, anon, authenticated;

-- تغییرهای مدیریتی پروفایل/بار از مرورگر نباید RLS را دور بزنند؛ مسیر قابل‌استفاده فقط RPCهای audit‌شونده زیر است.
drop policy if exists profiles_update_admin on public.profiles;
drop policy if exists loads_update_admin on public.loads;

-- Postgres has no built-in Persian status formatter; keep the activity feed independent of UI labels.
create or replace function public.admin_status_label(p_status text)
returns text
language sql
immutable
set search_path = public
as $$
  select case p_status
    when 'published' then 'منتشرشده'
    when 'receiving_offers' then 'در حال دریافت پیشنهاد'
    when 'agreed' then 'توافق‌شده'
    when 'awaiting_pickup' then 'در انتظار بارگیری'
    when 'in_transit' then 'در حال حمل'
    when 'delivered' then 'تحویل‌شده'
    when 'cancelled' then 'لغوشده'
    else p_status
  end;
$$;

-- یک خروجی واحد برای آمار واقعی و فعالیت‌های آخر داشبورد؛ فقط مدیر فعال آن را می‌خواند.
create or replace function public.admin_dashboard_summary()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_result jsonb;
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;

  select jsonb_build_object(
    'metrics', jsonb_build_object(
      'total_users', (select count(*) from public.profiles),
      'drivers', (select count(*) from public.profiles where role = 'driver'),
      'cargo_owners', (select count(*) from public.profiles where role = 'cargo_owner'),
      'blocked_users', (select count(*) from public.profiles where is_blocked),
      'total_loads', (select count(*) from public.loads),
      'active_loads', (select count(*) from public.loads where status in ('published', 'receiving_offers')),
      'active_shipments', (select count(*) from public.shipments where status in ('agreed', 'awaiting_pickup', 'in_transit')),
      'open_reports', (select count(*) from public.reports where status = 'open')
    ),
    'recent_activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'kind', activity.kind,
        'title', activity.title,
        'detail', activity.detail,
        'created_at', activity.created_at
      ) order by activity.created_at desc)
      from (
        select 'user_created'::text as kind,
          coalesce(p.display_name, 'کاربر جدید') as title,
          'ثبت‌نام کاربر جدید'::text as detail,
          p.created_at
        from public.profiles p

        union all

        select 'load_created'::text,
          l.title,
          'ثبت بار جدید: ' || l.origin_city || ' ← ' || l.destination_city,
          l.created_at
        from public.loads l

        union all

        select 'shipment_status'::text,
          coalesce(l.title, 'سفارش حمل'),
          'وضعیت سفارش: ' || public.admin_status_label(h.new_status::text),
          h.created_at
        from public.shipment_status_history h
        join public.shipments s on s.id = h.shipment_id
        join public.loads l on l.id = s.load_id

        union all

        select 'report_created'::text,
          r.subject,
          'گزارش جدید برای بررسی',
          r.created_at
        from public.reports r

        union all

        select a.action,
          case when a.action = 'user_blocked' then 'مسدودسازی کاربر'
               when a.action = 'user_unblocked' then 'رفع مسدودی کاربر'
               else 'تغییر وضعیت بار' end,
          coalesce(a.metadata ->> 'summary', 'اقدام مدیریتی ثبت شد'),
          a.created_at
        from public.admin_audit_log a

        order by created_at desc
        limit 12
      ) activity
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

-- جست‌وجوی مدیر شامل ایمیل auth.users است و به همین دلیل فقط داخل RPC محافظت‌شده انجام می‌شود.
create or replace function public.admin_list_users(
  p_search text default null,
  p_role public.user_role default null,
  p_status text default 'all',
  p_page integer default 1,
  p_page_size integer default 20
)
returns table (
  id uuid,
  email text,
  display_name text,
  phone text,
  city text,
  role public.user_role,
  truck_type text,
  truck_model text,
  plate_number text,
  is_blocked boolean,
  created_at timestamptz,
  updated_at timestamptz,
  load_count bigint,
  offer_count bigint,
  shipment_count bigint,
  total_count bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_page integer := least(greatest(coalesce(p_page, 1), 1), 10000);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 5), 50);
  v_search text := nullif(btrim(p_search), '');
  v_status text := coalesce(p_status, 'all');
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;
  if v_status not in ('all', 'active', 'blocked') then
    raise exception 'فیلتر وضعیت کاربر نامعتبر است';
  end if;
  if v_search is not null and char_length(v_search) > 100 then
    raise exception 'عبارت جست‌وجو بیش از حد طولانی است';
  end if;

  return query
  with filtered as (
    select p.id, u.email, p.display_name, p.phone, p.city, p.role, p.truck_type,
      p.truck_model, p.plate_number, p.is_blocked, p.created_at, p.updated_at
    from public.profiles p
    join auth.users u on u.id = p.id
    where (p_role is null or p.role = p_role)
      and (v_status = 'all' or (v_status = 'active' and not p.is_blocked) or (v_status = 'blocked' and p.is_blocked))
      and (v_search is null
        or coalesce(p.display_name, '') ilike '%' || v_search || '%'
        or coalesce(p.phone, '') ilike '%' || v_search || '%'
        or coalesce(u.email, '') ilike '%' || v_search || '%')
  )
  select f.id, f.email, f.display_name, f.phone, f.city, f.role, f.truck_type,
    f.truck_model, f.plate_number, f.is_blocked, f.created_at, f.updated_at,
    coalesce(loads.count, 0)::bigint,
    coalesce(offers.count, 0)::bigint,
    coalesce(shipments.count, 0)::bigint,
    count(*) over()::bigint
  from filtered f
  left join lateral (select count(*)::bigint as count from public.loads l where l.owner_id = f.id) loads on true
  left join lateral (select count(*)::bigint as count from public.freight_offers o where o.driver_id = f.id) offers on true
  left join lateral (select count(*)::bigint as count from public.shipments s where s.owner_id = f.id or s.driver_id = f.id) shipments on true
  order by f.created_at desc
  limit v_page_size offset ((v_page - 1) * v_page_size);
end;
$$;

create or replace function public.admin_get_user_details(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_result jsonb;
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;

  select jsonb_build_object(
    'id', p.id,
    'email', u.email,
    'display_name', p.display_name,
    'phone', p.phone,
    'city', p.city,
    'role', p.role,
    'truck_type', p.truck_type,
    'truck_model', p.truck_model,
    'plate_number', p.plate_number,
    'is_blocked', p.is_blocked,
    'created_at', p.created_at,
    'updated_at', p.updated_at,
    'load_count', (select count(*) from public.loads l where l.owner_id = p.id),
    'offer_count', (select count(*) from public.freight_offers o where o.driver_id = p.id),
    'shipment_count', (select count(*) from public.shipments s where s.owner_id = p.id or s.driver_id = p.id),
    'recent_loads', coalesce((
      select jsonb_agg(to_jsonb(recent_loads))
      from (
        select l.id, l.title, l.origin_city, l.destination_city, l.status, l.created_at
        from public.loads l where l.owner_id = p.id
        order by l.created_at desc limit 6
      ) recent_loads
    ), '[]'::jsonb)
  ) into v_result
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = p_user_id;

  if v_result is null then
    raise exception 'کاربر پیدا نشد';
  end if;
  return v_result;
end;
$$;

create or replace function public.admin_set_user_blocked(p_user_id uuid, p_blocked boolean)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_current boolean; v_name text;
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;
  if p_user_id is null or p_blocked is null then
    raise exception 'کاربر یا وضعیت آن نامعتبر است';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'برای جلوگیری از قفل‌شدن حساب، نمی‌توانید حساب مدیریت فعلی را مسدود کنید';
  end if;

  select p.is_blocked, coalesce(p.display_name, 'کاربر') into v_current, v_name
  from public.profiles p where p.id = p_user_id for update;
  if not found then
    raise exception 'کاربر پیدا نشد';
  end if;
  if v_current is not distinct from p_blocked then return; end if;

  update public.profiles set is_blocked = p_blocked where id = p_user_id;
  insert into public.admin_audit_log (admin_id, action, target_user_id, metadata)
  values (
    auth.uid(),
    case when p_blocked then 'user_blocked' else 'user_unblocked' end,
    p_user_id,
    jsonb_build_object('summary', case when p_blocked then 'حساب «' || v_name || '» مسدود شد' else 'مسدودی حساب «' || v_name || '» برداشته شد' end)
  );
end;
$$;

-- فهرست بارها همراه اطلاعات صاحب بار، بدون دادن دسترسی مستقیم به auth.users در مرورگر.
create or replace function public.admin_list_loads(
  p_search text default null,
  p_status public.load_status default null,
  p_page integer default 1,
  p_page_size integer default 20
)
returns table (
  id uuid,
  owner_id uuid,
  title text,
  origin_city text,
  destination_city text,
  cargo_type text,
  required_truck_type text,
  weight_value numeric,
  weight_unit text,
  proposed_fare bigint,
  loading_date date,
  status public.load_status,
  created_at timestamptz,
  owner_name text,
  owner_email text,
  owner_phone text,
  offer_count bigint,
  has_shipment boolean,
  total_count bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_page integer := least(greatest(coalesce(p_page, 1), 1), 10000);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 5), 50);
  v_search text := nullif(btrim(p_search), '');
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;
  if v_search is not null and char_length(v_search) > 100 then
    raise exception 'عبارت جست‌وجو بیش از حد طولانی است';
  end if;

  return query
  with filtered as (
    select l.id, l.owner_id, l.title, l.origin_city, l.destination_city, l.cargo_type,
      l.required_truck_type, l.weight_value, l.weight_unit, l.proposed_fare, l.loading_date,
      l.status, l.created_at, p.display_name as owner_name, u.email as owner_email, p.phone as owner_phone
    from public.loads l
    join public.profiles p on p.id = l.owner_id
    join auth.users u on u.id = p.id
    where (p_status is null or l.status = p_status)
      and (v_search is null
        or l.title ilike '%' || v_search || '%'
        or l.origin_city ilike '%' || v_search || '%'
        or l.destination_city ilike '%' || v_search || '%'
        or coalesce(p.display_name, '') ilike '%' || v_search || '%'
        or coalesce(u.email, '') ilike '%' || v_search || '%')
  )
  select f.id, f.owner_id, f.title, f.origin_city, f.destination_city, f.cargo_type,
    f.required_truck_type, f.weight_value, f.weight_unit, f.proposed_fare, f.loading_date,
    f.status, f.created_at, f.owner_name, f.owner_email, f.owner_phone,
    coalesce(offers.count, 0)::bigint,
    exists (select 1 from public.shipments s where s.load_id = f.id),
    count(*) over()::bigint
  from filtered f
  left join lateral (select count(*)::bigint as count from public.freight_offers o where o.load_id = f.id) offers on true
  order by f.created_at desc
  limit v_page_size offset ((v_page - 1) * v_page_size);
end;
$$;

create or replace function public.admin_get_load_details(p_load_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_result jsonb;
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;

  select jsonb_build_object(
    'load', jsonb_build_object(
      'id', l.id, 'title', l.title, 'cargo_description', l.cargo_description,
      'origin_city', l.origin_city, 'destination_city', l.destination_city,
      'weight_value', l.weight_value, 'weight_unit', l.weight_unit,
      'cargo_type', l.cargo_type, 'required_truck_type', l.required_truck_type,
      'proposed_fare', l.proposed_fare, 'loading_date', l.loading_date,
      'notes', l.notes, 'status', l.status, 'created_at', l.created_at, 'updated_at', l.updated_at
    ),
    'owner', jsonb_build_object(
      'id', p.id, 'display_name', p.display_name, 'email', u.email,
      'phone', p.phone, 'city', p.city, 'is_blocked', p.is_blocked
    ),
    'private_details', case when d.load_id is null then null else jsonb_build_object(
      'pickup_address', d.pickup_address, 'delivery_address', d.delivery_address
    ) end,
    'offers', coalesce((
      select jsonb_agg(to_jsonb(recent_offers))
      from (
        select o.id, o.offered_fare, o.note, o.status, o.created_at,
          dp.display_name as driver_name, dp.phone as driver_phone, dp.truck_type
        from public.freight_offers o
        join public.profiles dp on dp.id = o.driver_id
        where o.load_id = l.id
        order by o.created_at desc limit 20
      ) recent_offers
    ), '[]'::jsonb),
    'shipment', (
      select jsonb_build_object('id', s.id, 'status', s.status, 'agreed_fare', s.agreed_fare, 'created_at', s.created_at)
      from public.shipments s where s.load_id = l.id
    )
  ) into v_result
  from public.loads l
  join public.profiles p on p.id = l.owner_id
  join auth.users u on u.id = p.id
  left join public.load_private_details d on d.load_id = l.id
  where l.id = p_load_id;

  if v_result is null then
    raise exception 'بار پیدا نشد';
  end if;
  return v_result;
end;
$$;

-- حذف فیزیکی بار وجود ندارد؛ مدیر فقط وضعیت معتبر را تغییر می‌دهد و دلیل اقدام ثبت می‌شود.
create or replace function public.admin_set_load_status(p_load_id uuid, p_new_status public.load_status, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_load public.loads%rowtype;
  v_shipment public.shipments%rowtype;
  v_has_shipment boolean := false;
  v_reason text := nullif(btrim(p_reason), '');
begin
  if not public.is_active_user() or not public.is_admin() then
    raise exception 'دسترسی مدیریت مجاز نیست';
  end if;
  if p_new_status is null then
    raise exception 'وضعیت جدید بار الزامی است';
  end if;
  if coalesce(char_length(v_reason), 0) > 500 then
    raise exception 'توضیح اقدام مدیریتی طولانی است';
  end if;

  select * into v_load from public.loads where id = p_load_id for update;
  if not found then
    raise exception 'بار پیدا نشد';
  end if;
  if v_load.status = p_new_status then return; end if;

  select * into v_shipment from public.shipments where load_id = p_load_id for update;
  v_has_shipment := found;

  if v_has_shipment then
    if p_new_status not in ('agreed', 'awaiting_pickup', 'in_transit', 'delivered', 'cancelled') then
      raise exception 'برای بار دارای سفارش، وضعیت انتخاب‌شده معتبر نیست';
    end if;
    update public.shipments set status = p_new_status where id = v_shipment.id;
    insert into public.shipment_status_history (shipment_id, old_status, new_status, changed_by, note)
    values (v_shipment.id, v_shipment.status, p_new_status, auth.uid(), coalesce(v_reason, 'تغییر وضعیت توسط مدیر'));
  elsif p_new_status not in ('published', 'receiving_offers', 'cancelled') then
    raise exception 'بار بدون سفارش فقط می‌تواند منتشر، در حال دریافت پیشنهاد یا لغوشده باشد';
  end if;

  update public.loads set status = p_new_status where id = p_load_id;
  insert into public.admin_audit_log (admin_id, action, target_load_id, metadata)
  values (
    auth.uid(), 'load_status_changed', p_load_id,
    jsonb_build_object(
      'old_status', v_load.status,
      'new_status', p_new_status,
      'reason', v_reason,
      'summary', 'وضعیت بار «' || v_load.title || '» از «' || public.admin_status_label(v_load.status::text) || '» به «' || public.admin_status_label(p_new_status::text) || '» تغییر کرد'
    )
  );
end;
$$;

-- Least privilege for administration RPCs.
revoke all on function public.admin_status_label(text) from public, anon, authenticated;
revoke all on function public.admin_dashboard_summary() from public, anon;
revoke all on function public.admin_list_users(text, public.user_role, text, integer, integer) from public, anon;
revoke all on function public.admin_get_user_details(uuid) from public, anon;
revoke all on function public.admin_set_user_blocked(uuid, boolean) from public, anon;
revoke all on function public.admin_list_loads(text, public.load_status, integer, integer) from public, anon;
revoke all on function public.admin_get_load_details(uuid) from public, anon;
revoke all on function public.admin_set_load_status(uuid, public.load_status, text) from public, anon;

grant execute on function public.admin_dashboard_summary() to authenticated;
grant execute on function public.admin_list_users(text, public.user_role, text, integer, integer) to authenticated;
grant execute on function public.admin_get_user_details(uuid) to authenticated;
grant execute on function public.admin_set_user_blocked(uuid, boolean) to authenticated;
grant execute on function public.admin_list_loads(text, public.load_status, integer, integer) to authenticated;
grant execute on function public.admin_get_load_details(uuid) to authenticated;
grant execute on function public.admin_set_load_status(uuid, public.load_status, text) to authenticated;


-- ایجاد اولین مدیر (فقط پس از آنکه کاربر از طریق Auth ثبت‌نام کرد، در SQL Editor مالک اجرا شود):
-- insert into public.app_admins (user_id) values ('UUID-کاربر-مدیر');
-- هیچ راهی در فرانت‌اند برای اجرای دستور بالا وجود ندارد.

-- چک‌های دستی پیشنهادی RLS (با دو حساب تست جداگانه اجرا کنید):
-- 1) راننده A نباید بتواند select از profiles برای کاربر نامرتبط یا load_private_details یک بار باز انجام دهد.
-- 2) صاحب بار B نباید بتواند select/update پیشنهاد یا بار صاحب بار C را انجام دهد.
-- 3) راننده نباید بتواند update مستقیم loads یا insert مستقیم freight_offers انجام دهد.
-- 4) هم‌زمان accept_freight_offer را برای دو پیشنهاد یک بار اجرا کنید: تنها یکی باید سفارش بسازد.
-- 5) کاربر عادی نباید بتواند select از app_admins یا با update profiles نقش مدیر بگیرد.
