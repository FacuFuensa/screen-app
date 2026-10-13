create function public.ensure_profile(p_name text) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare r public.profiles;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  insert into profiles (id, display_name) values (auth.uid(), trim(p_name))
  on conflict (id) do update set display_name = excluded.display_name
  returning * into r;
  return r;
end $$;

create function public.create_invite() returns text
language plpgsql security definer set search_path = public as $$
declare code text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if public.my_pair_id() is not null then raise exception 'already_paired'; end if;
  delete from pairs where user_a = auth.uid() and user_b is null;
  loop
    code := lpad(floor(random() * 1000000)::int::text, 6, '0');
    begin
      insert into pairs (user_a, invite_code) values (auth.uid(), code);
      return code;
    exception when unique_violation then
      -- code collision: try another one
    end;
  end loop;
end $$;

create function public.join_pair(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare p public.pairs;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if public.my_pair_id() is not null then raise exception 'already_paired'; end if;
  select * into p from pairs where invite_code = trim(p_code) and user_b is null for update;
  if not found then raise exception 'invalid_code'; end if;
  if p.user_a = auth.uid() then raise exception 'own_code'; end if;
  delete from pairs where user_a = auth.uid() and user_b is null;
  update pairs set user_b = auth.uid() where id = p.id;
  return p.id;
end $$;

-- Each side keeps its local limits; requests and events go with the pair.
create function public.leave_pair() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from pairs where id = public.my_pair_id();
end $$;

create function public.heartbeat(p_auth_status text, p_apns_token text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare prev text; pid uuid := public.my_pair_id(); eid uuid;
begin
  select auth_status into prev from profiles where id = auth.uid() for update;
  if not found then raise exception 'no_profile'; end if;
  update profiles
     set last_seen_at = now(), auth_status = p_auth_status,
         apns_token = coalesce(p_apns_token, apns_token), silent_alerted_at = null
   where id = auth.uid();
  if prev = 'approved' and p_auth_status <> 'approved' and pid is not null then
    insert into events (pair_id, actor, kind) values (pid, auth.uid(), 'auth_revoked')
    returning id into eid;
  end if;
  return eid;
end $$;

-- Called by the watchdog edge function (service role) every 30 min.
create function public.watchdog_scan() returns table (event_id uuid)
language plpgsql security definer set search_path = public as $$
begin
  return query
  with silent as (
    update profiles pr set silent_alerted_at = now()
     where pr.last_seen_at < now() - interval '24 hours'
       and pr.silent_alerted_at is null
       and exists (select 1 from pairs pa
                    where (pa.user_a = pr.id or pa.user_b = pr.id) and pa.user_b is not null)
    returning pr.id
  )
  insert into events (pair_id, actor, kind)
  select pa.id, s.id, 'silent_24h'
    from silent s
    join pairs pa on (pa.user_a = s.id or pa.user_b = s.id) and pa.user_b is not null
  returning id;
end $$;

revoke execute on function public.ensure_profile(text), public.create_invite(), public.join_pair(text),
  public.leave_pair(), public.heartbeat(text, text), public.watchdog_scan() from public, anon;
grant execute on function public.ensure_profile(text), public.create_invite(), public.join_pair(text),
  public.leave_pair(), public.heartbeat(text, text) to authenticated;
revoke execute on function public.watchdog_scan() from authenticated;
