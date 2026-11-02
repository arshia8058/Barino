
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

