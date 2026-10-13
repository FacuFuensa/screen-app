-- Mirrors ScreenCore.LimitChange: anything that frees time is a loosening.
create function public.window_contains(p_start int, p_end int, p_minute int) returns boolean
language sql immutable as $$
  select case when p_start < p_end then p_minute >= p_start and p_minute < p_end
              else p_minute >= p_start or p_minute < p_end end
$$;

create function public.window_covers(n_start int, n_end int, o_start int, o_end int) returns boolean
language sql immutable as $$
  select case
    when o_start is null then true
    when n_start is null then false
    else not exists (
      select 1 from generate_series(0, 1439) m
       where public.window_contains(o_start, o_end, m)
         and not public.window_contains(n_start, n_end, m))
  end
$$;

create function public.is_loosening(
  o_min int, n_min int, o_ws int, o_we int, n_ws int, n_we int, p_removes_apps boolean
) returns boolean language sql immutable as $$
  select coalesce(p_removes_apps, false)
      or (o_min is not null and (n_min is null or n_min > o_min))
      or not public.window_covers(n_ws, n_we, o_ws, o_we)
$$;

create function public.save_group(
  p_id uuid, p_name text, p_app_count int,
  p_daily_minutes int default null, p_window_start int default null, p_window_end int default null,
  p_removes_apps boolean default false
) returns text
language plpgsql security definer set search_path = public as $$
declare g public.limit_groups; pid uuid := public.my_pair_id(); n int;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into g from limit_groups where id = p_id for update;
  if not found then
    select count(*) into n from limit_groups where owner = auth.uid();
    if n >= 5 then raise exception 'too_many_groups'; end if;
    insert into limit_groups (id, owner, name, app_count, daily_minutes, window_start, window_end)
    values (p_id, auth.uid(), trim(p_name), p_app_count, p_daily_minutes, p_window_start, p_window_end);
    if pid is not null then
      insert into events (pair_id, actor, kind, group_id) values (pid, auth.uid(), 'group_created', p_id);
    end if;
    return 'created';
  end if;
  if g.owner <> auth.uid() then raise exception 'not_owner'; end if;
  if pid is not null and (
       p_app_count < g.app_count
       or public.is_loosening(g.daily_minutes, p_daily_minutes, g.window_start, g.window_end,
                              p_window_start, p_window_end, p_removes_apps)) then
    raise exception 'loosening_requires_approval';
  end if;
  if (g.name, g.app_count, g.daily_minutes, g.window_start, g.window_end)
     is not distinct from (trim(p_name), p_app_count, p_daily_minutes, p_window_start, p_window_end) then
    return 'unchanged';
  end if;
  update limit_groups
     set name = trim(p_name), app_count = p_app_count, daily_minutes = p_daily_minutes,
         window_start = p_window_start, window_end = p_window_end, updated_at = now()
   where id = p_id;
  if pid is not null and (g.app_count, g.daily_minutes, g.window_start, g.window_end)
     is distinct from (p_app_count, p_daily_minutes, p_window_start, p_window_end) then
    insert into events (pair_id, actor, kind, group_id, data)
    values (pid, auth.uid(), 'limit_tightened', p_id,
            jsonb_build_object('from_minutes', g.daily_minutes, 'to_minutes', p_daily_minutes));
  end if;
  return 'updated';
end $$;

-- Deleting frees time, so with a partner it goes through request_loosen.
create function public.delete_group(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_pair_id() is not null then raise exception 'loosening_requires_approval'; end if;
  delete from limit_groups where id = p_id and owner = auth.uid();
end $$;

revoke execute on function public.save_group(uuid, text, int, int, int, int, boolean),
  public.delete_group(uuid) from public, anon;
grant execute on function public.save_group(uuid, text, int, int, int, int, boolean),
  public.delete_group(uuid) to authenticated;
