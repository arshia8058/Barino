-- Manual application of the admin-console migration: part 8 of 8.
-- Run parts in order after the existing Barino base schema; stop on any error.

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
