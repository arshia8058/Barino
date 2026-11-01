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
  id = auth.uid() or public.is_admin() or exists (
    select 1 from public.shipments s
    where (s.owner_id = auth.uid() and s.driver_id = profiles.id)
       or (s.driver_id = auth.uid() and s.owner_id = profiles.id)
  )
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid() and not is_blocked)
  with check (id = auth.uid());
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists loads_select_authorized on public.loads;
create policy loads_select_authorized on public.loads for select to authenticated using (
  public.is_admin()
  or owner_id = auth.uid()
  or (status in ('published', 'receiving_offers') and exists (select 1 from public.profiles p where p.id = auth.uid() and not p.is_blocked))
  or exists (select 1 from public.shipments s where s.load_id = loads.id and (s.owner_id = auth.uid() or s.driver_id = auth.uid()))
);
drop policy if exists loads_update_owner on public.loads;
create policy loads_update_owner on public.loads for update to authenticated
  using (owner_id = auth.uid() and status in ('published', 'receiving_offers'))
  with check (owner_id = auth.uid());
drop policy if exists loads_update_admin on public.loads;
create policy loads_update_admin on public.loads for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists private_details_select_authorized on public.load_private_details;
create policy private_details_select_authorized on public.load_private_details for select to authenticated using (
  public.is_admin()
  or exists (select 1 from public.loads l where l.id = load_private_details.load_id and l.owner_id = auth.uid())
  or exists (select 1 from public.shipments s where s.load_id = load_private_details.load_id and (s.owner_id = auth.uid() or s.driver_id = auth.uid()))
);

drop policy if exists offers_select_authorized on public.freight_offers;
create policy offers_select_authorized on public.freight_offers for select to authenticated using (
  public.is_admin() or driver_id = auth.uid() or exists (
    select 1 from public.loads l where l.id = freight_offers.load_id and l.owner_id = auth.uid()
  )
);

drop policy if exists shipments_select_authorized on public.shipments;
create policy shipments_select_authorized on public.shipments for select to authenticated using (
  public.is_admin() or owner_id = auth.uid() or driver_id = auth.uid()
);

drop policy if exists shipment_history_select_authorized on public.shipment_status_history;
create policy shipment_history_select_authorized on public.shipment_status_history for select to authenticated using (
  public.is_admin() or exists (
    select 1 from public.shipments s where s.id = shipment_status_history.shipment_id
      and (s.owner_id = auth.uid() or s.driver_id = auth.uid())
  )
);

drop policy if exists reports_select_authorized on public.reports;
create policy reports_select_authorized on public.reports for select to authenticated using (reporter_id = auth.uid() or public.is_admin());
drop policy if exists reports_insert_self on public.reports;
create policy reports_insert_self on public.reports for insert to authenticated with check (
  reporter_id = auth.uid() and status = 'open' and resolved_at is null and resolved_by is null
);
drop policy if exists reports_update_admin on public.reports;
create policy reports_update_admin on public.reports for update to authenticated using (public.is_admin()) with check (public.is_admin());
