-- Screen: two adults limiting each other's screen time.
-- Clients only READ tables; every write goes through SECURITY DEFINER RPCs
-- so "loosening needs approval" cannot be bypassed from the client.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  apns_token text,
  last_seen_at timestamptz,
  auth_status text not null default 'unknown'
    check (auth_status in ('unknown', 'approved', 'denied', 'notDetermined')),
  silent_alerted_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.pairs (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid references public.profiles(id) on delete cascade,
  invite_code text not null unique,
  created_at timestamptz not null default now(),
  check (user_a <> user_b)
);
create unique index pairs_user_a_key on public.pairs(user_a);
create unique index pairs_user_b_key on public.pairs(user_b) where user_b is not null;

-- Metadata mirror so the partner can see limits. App tokens never leave the device.
create table public.limit_groups (
  id uuid primary key,
  owner uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  app_count int not null check (app_count >= 0),
  daily_minutes int check (daily_minutes between 1 and 1440),
  window_start int check (window_start between 0 and 1439),
  window_end int check (window_end between 0 and 1439),
  updated_at timestamptz not null default now(),
  check ((window_start is null) = (window_end is null))
);

create table public.requests (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  from_user uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('extra_time', 'loosen_limit')),
  group_id uuid references public.limit_groups(id) on delete set null,
  minutes int check (minutes in (5, 15, 30)),
  payload jsonb,
  message text check (char_length(message) <= 140),
  status text not null default 'pending'
    check (status in ('pending', 'granted', 'denied', 'superseded')),
  granted_minutes int check (granted_minutes between 1 and 120),
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 minutes',
  answered_at timestamptz
);
create index requests_pair_created on public.requests(pair_id, created_at desc);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  actor uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in (
    'threshold_80', 'limit_reached', 'wildcard_used', 'auth_revoked', 'silent_24h',
    'limit_tightened', 'group_created', 'request_granted', 'request_denied')),
  group_id uuid references public.limit_groups(id) on delete set null,
  data jsonb not null default '{}'::jsonb,
  client_id text unique,
  created_at timestamptz not null default now()
);
create index events_pair_created on public.events(pair_id, created_at desc);

-- Helpers (SECURITY DEFINER so policies can use them without recursing).
create function public.my_pair_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.pairs
  where (user_a = auth.uid() or user_b = auth.uid()) and user_b is not null
  limit 1
$$;

create function public.partner_id() returns uuid
language sql stable security definer set search_path = public as $$
  select case when user_a = auth.uid() then user_b else user_a end
  from public.pairs where id = public.my_pair_id()
$$;

alter table public.profiles enable row level security;
alter table public.pairs enable row level security;
alter table public.limit_groups enable row level security;
alter table public.requests enable row level security;
alter table public.events enable row level security;

create policy profiles_read on public.profiles for select to authenticated
  using (id = auth.uid() or id = public.partner_id());
create policy pairs_read on public.pairs for select to authenticated
  using (user_a = auth.uid() or user_b = auth.uid());
create policy groups_read on public.limit_groups for select to authenticated
  using (owner = auth.uid() or owner = public.partner_id());
create policy requests_read on public.requests for select to authenticated
  using (pair_id = public.my_pair_id());
create policy events_read on public.events for select to authenticated
  using (pair_id = public.my_pair_id());

revoke all on public.profiles, public.pairs, public.limit_groups, public.requests, public.events
  from anon, authenticated;
grant select on public.profiles, public.pairs, public.limit_groups, public.requests, public.events
  to authenticated;
