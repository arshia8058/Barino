-- Barino security hardening: require verified email for all data access.
-- Applied after the initial schema migration.

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

-- RLS policies are recreated with a verified-email gate.
drop policy if exists profiles_select_authorized on public.profiles;
create policy profiles_select_authorized on public.profiles for select to authenticated using (
  public.is_confirmed_user() and (id = auth.uid() or public.is_admin() or exists (
    select 1 from public.shipments s
    where (s.owner_id = auth.uid() and s.driver_id = profiles.id)
       or (s.driver_id = auth.uid() and s.owner_id = profiles.id)
  ))
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
  using (public.is_confirmed_user() and id = auth.uid() and not is_blocked)
  with check (public.is_confirmed_user() and id = auth.uid());
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated
  using (public.is_confirmed_user() and public.is_admin()) with check (public.is_confirmed_user() and public.is_admin());

drop policy if exists loads_select_authorized on public.loads;
create policy loads_select_authorized on public.loads for select to authenticated using (
  public.is_confirmed_user() and (
    public.is_admin()
    or owner_id = auth.uid()
    or (status in ('published', 'receiving_offers') and exists (select 1 from public.profiles p where p.id = auth.uid() and not p.is_blocked))
    or exists (select 1 from public.shipments s where s.load_id = loads.id and (s.owner_id = auth.uid() or s.driver_id = auth.uid()))
  )
);
drop policy if exists loads_update_owner on public.loads;
create policy loads_update_owner on public.loads for update to authenticated
  using (public.is_confirmed_user() and owner_id = auth.uid() and status in ('published', 'receiving_offers'))
  with check (public.is_confirmed_user() and owner_id = auth.uid());
drop policy if exists loads_update_admin on public.loads;
create policy loads_update_admin on public.loads for update to authenticated using (public.is_confirmed_user() and public.is_admin()) with check (public.is_confirmed_user() and public.is_admin());

drop policy if exists private_details_select_authorized on public.load_private_details;
create policy private_details_select_authorized on public.load_private_details for select to authenticated using (
  public.is_confirmed_user() and (
    public.is_admin()
    or exists (select 1 from public.loads l where l.id = load_private_details.load_id and l.owner_id = auth.uid())
    or exists (select 1 from public.shipments s where s.load_id = load_private_details.load_id and (s.owner_id = auth.uid() or s.driver_id = auth.uid()))
  )
);

drop policy if exists offers_select_authorized on public.freight_offers;
create policy offers_select_authorized on public.freight_offers for select to authenticated using (
  public.is_confirmed_user() and (public.is_admin() or driver_id = auth.uid() or exists (
    select 1 from public.loads l where l.id = freight_offers.load_id and l.owner_id = auth.uid()
  ))
);

drop policy if exists shipments_select_authorized on public.shipments;
create policy shipments_select_authorized on public.shipments for select to authenticated using (
  public.is_confirmed_user() and (public.is_admin() or owner_id = auth.uid() or driver_id = auth.uid())
);

drop policy if exists shipment_history_select_authorized on public.shipment_status_history;
create policy shipment_history_select_authorized on public.shipment_status_history for select to authenticated using (
  public.is_confirmed_user() and (public.is_admin() or exists (
    select 1 from public.shipments s where s.id = shipment_status_history.shipment_id
      and (s.owner_id = auth.uid() or s.driver_id = auth.uid())
  ))
);

drop policy if exists reports_select_authorized on public.reports;
create policy reports_select_authorized on public.reports for select to authenticated using (public.is_confirmed_user() and (reporter_id = auth.uid() or public.is_admin()));
drop policy if exists reports_insert_self on public.reports;
create policy reports_insert_self on public.reports for insert to authenticated with check (
  public.is_confirmed_user() and reporter_id = auth.uid() and status = 'open' and resolved_at is null and resolved_by is null
);
drop policy if exists reports_update_admin on public.reports;
create policy reports_update_admin on public.reports for update to authenticated using (public.is_confirmed_user() and public.is_admin()) with check (public.is_confirmed_user() and public.is_admin());

-- Sensitive RPCs independently enforce verified email.
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
  if not public.is_confirmed_user() then raise exception 'ابتدا ایمیل خود را تأیید کنید'; end if;
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
  if not public.is_confirmed_user() then raise exception 'ابتدا ایمیل خود را تأیید کنید'; end if;
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
  if not public.is_confirmed_user() then raise exception 'ابتدا ایمیل خود را تأیید کنید'; end if;
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
  if not public.is_confirmed_user() then raise exception 'ابتدا ایمیل خود را تأیید کنید'; end if;
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
  if not public.is_confirmed_user() then raise exception 'ابتدا ایمیل خود را تأیید کنید'; end if;
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
  if not public.is_confirmed_user() then raise exception 'ابتدا ایمیل خود را تأیید کنید'; end if;
  select * into v_shipment from public.shipments where id = p_shipment_id;
  if not found or not (public.is_admin() or auth.uid() = v_shipment.owner_id or auth.uid() = v_shipment.driver_id) then raise exception 'دسترسی به اطلاعات خصوصی مجاز نیست'; end if;
  v_other := case when auth.uid() = v_shipment.owner_id then v_shipment.driver_id else v_shipment.owner_id end;
  return query select p.display_name, p.phone, d.pickup_address, d.delivery_address
    from public.load_private_details d join public.profiles p on p.id = v_other
    where d.load_id = v_shipment.load_id;
end;
$$;

-- Permissions for the verification helper.
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_confirmed_user() to authenticated;
grant execute on function public.create_load_with_private_details(jsonb) to authenticated;
grant execute on function public.update_load_with_private_details(uuid,jsonb) to authenticated;
grant execute on function public.submit_freight_offer(uuid,bigint,text) to authenticated;
grant execute on function public.accept_freight_offer(uuid) to authenticated;
grant execute on function public.change_shipment_status(uuid,public.load_status,text) to authenticated;
grant execute on function public.get_shipment_private_details(uuid) to authenticated;
revoke all on table public.app_admins from anon, authenticated;
