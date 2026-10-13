-- The requester can take back a request while it is still pending.
alter table public.requests drop constraint requests_status_check;
alter table public.requests add constraint requests_status_check
  check (status in ('pending', 'granted', 'denied', 'superseded', 'cancelled'));

create function public.cancel_request(p_request_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r public.requests;
begin
  select * into r from requests where id = p_request_id for update;
  if not found or r.from_user is distinct from auth.uid() then raise exception 'not_found'; end if;
  if r.status <> 'pending' then raise exception 'not_pending'; end if;
  update requests set status = 'cancelled' where id = r.id;
end $$;

revoke execute on function public.cancel_request(uuid) from public, anon;
grant execute on function public.cancel_request(uuid) to authenticated;
