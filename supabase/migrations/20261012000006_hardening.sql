-- Security advisor follow-ups.
-- The RLS helpers are only meaningful for signed-in users.
revoke execute on function public.my_pair_id(), public.partner_id() from public, anon;
grant execute on function public.my_pair_id(), public.partner_id() to authenticated;

-- Pure helpers: pin search_path so a caller cannot shadow what they resolve to.
alter function public.window_contains(int, int, int) set search_path = public;
alter function public.window_covers(int, int, int, int) set search_path = public;
alter function public.is_loosening(int, int, int, int, int, int, boolean) set search_path = public;
