create function public.request_extra_time(p_group_id uuid, p_minutes int, p_message text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid := public.my_pair_id(); rid uuid;
begin
  if pid is null then raise exception 'not_paired'; end if;
  if not exists (select 1 from limit_groups where id = p_group_id and owner = auth.uid()) then
    raise exception 'not_owner';
  end if;
  if p_minutes is null or p_minutes not in (5, 15, 30) then raise exception 'invalid_minutes'; end if;
  update requests set status = 'superseded'
   where group_id = p_group_id and kind = 'extra_time' and status = 'pending';
  insert into requests (pair_id, from_user, kind, group_id, minutes, message)
  values (pid, auth.uid(), 'extra_time', p_group_id, p_minutes, nullif(trim(p_message), ''))
  returning id into rid;
  return rid;
end $$;

create function public.request_loosen(p_group_id uuid, p_payload jsonb, p_message text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid := public.my_pair_id(); rid uuid;
begin
  if pid is null then raise exception 'not_paired'; end if;
  if not exists (select 1 from limit_groups where id = p_group_id and owner = auth.uid()) then
    raise exception 'not_owner';
  end if;
  if jsonb_typeof(p_payload) is distinct from 'object' then raise exception 'invalid_payload'; end if;
  if not coalesce((p_payload->>'delete')::boolean, false)
     and not (p_payload ?& array['name', 'app_count', 'daily_minutes', 'window_start', 'window_end']) then
    raise exception 'invalid_payload';
  end if;
  update requests set status = 'superseded'
   where group_id = p_group_id and kind = 'loosen_limit' and status = 'pending';
  insert into requests (pair_id, from_user, kind, group_id, payload, message)
  values (pid, auth.uid(), 'loosen_limit', p_group_id, p_payload, nullif(trim(p_message), ''))
  returning id into rid;
  return rid;
end $$;

create function public.answer_request(p_request_id uuid, p_grant boolean, p_minutes int default null)
returns public.requests language plpgsql security definer set search_path = public as $$
declare r public.requests; pid uuid := public.my_pair_id(); p jsonb; del boolean := false;
begin
  select * into r from requests where id = p_request_id for update;
  if not found or r.pair_id is distinct from pid then raise exception 'not_found'; end if;
  if r.from_user = auth.uid() then raise exception 'cannot_answer_own'; end if;
  if r.status <> 'pending' then raise exception 'not_pending'; end if;
  if now() >= r.expires_at then raise exception 'request_expired'; end if;
  if p_grant and r.kind = 'extra_time' and p_minutes is not null and (p_minutes < 1 or p_minutes > 120) then
    raise exception 'invalid_minutes';
  end if;

  if p_grant and r.kind = 'loosen_limit' then
    p := r.payload;
    del := coalesce((p->>'delete')::boolean, false);
    if not del then
      update limit_groups
         set name = p->>'name', app_count = (p->>'app_count')::int,
             daily_minutes = (p->>'daily_minutes')::int,
             window_start = (p->>'window_start')::int, window_end = (p->>'window_end')::int,
             updated_at = now()
       where id = r.group_id;
    end if;
  end if;

  update requests
     set status = case when p_grant then 'granted' else 'denied' end,
         granted_minutes = case when p_grant and r.kind = 'extra_time' then coalesce(p_minutes, r.minutes) end,
         answered_at = now()
   where id = r.id
  returning * into r;

  insert into events (pair_id, actor, kind, group_id, data)
  values (pid, auth.uid(), case when p_grant then 'request_granted' else 'request_denied' end, r.group_id,
          jsonb_build_object('request_id', r.id, 'request_kind', r.kind, 'minutes', r.granted_minutes));

  -- Last, so the event above can still reference the group (FKs then set it null).
  if del then delete from limit_groups where id = r.group_id; end if;
  return r;
end $$;

create function public.mark_applied(p_request_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update requests set applied_at = now()
   where id = p_request_id and from_user = auth.uid() and status = 'granted' and applied_at is null;
end $$;

create function public.log_event(p_kind text, p_group_id uuid default null,
                                 p_data jsonb default '{}'::jsonb, p_client_id text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare pid uuid := public.my_pair_id(); gid uuid := p_group_id; eid uuid;
begin
  if p_kind not in ('threshold_80', 'limit_reached', 'wildcard_used') then raise exception 'invalid_kind'; end if;
  if pid is null then return null; end if;
  -- The group may have been deleted while the event sat in the device outbox.
  if gid is not null and not exists (select 1 from limit_groups where id = gid and owner = auth.uid()) then
    gid := null;
  end if;
  insert into events (pair_id, actor, kind, group_id, data, client_id)
  values (pid, auth.uid(), p_kind, gid, coalesce(p_data, '{}'::jsonb), p_client_id)
  on conflict (client_id) do nothing
  returning id into eid;
  return eid;
end $$;

revoke execute on function public.request_extra_time(uuid, int, text), public.request_loosen(uuid, jsonb, text),
  public.answer_request(uuid, boolean, int), public.mark_applied(uuid),
  public.log_event(text, uuid, jsonb, text) from public, anon;
grant execute on function public.request_extra_time(uuid, int, text), public.request_loosen(uuid, jsonb, text),
  public.answer_request(uuid, boolean, int), public.mark_applied(uuid),
  public.log_event(text, uuid, jsonb, text) to authenticated;
