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
