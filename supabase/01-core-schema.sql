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

-- یک public profile امن برای مقایسه پیشنهادها؛ شماره، پلاک و آدرس در آن نیست.
create or replace view public.driver_public_profiles
with (security_invoker = false) as
  select id, display_name, truck_type, truck_model
  from public.profiles
  where role = 'driver' and is_blocked = false and public.is_confirmed_user();

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
