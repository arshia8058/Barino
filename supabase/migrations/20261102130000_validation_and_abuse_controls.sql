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
