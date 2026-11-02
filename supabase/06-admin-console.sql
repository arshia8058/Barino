

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
