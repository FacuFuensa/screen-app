create or replace function public.create_invite() returns text
language plpgsql security definer set search_path = public as $$
declare code text;
begin
  -- Pairing is rare; serializing it is what keeps "one pair per user" true
  -- (the two unique indexes cannot see across user_a and user_b).
  lock table public.pairs in share row exclusive mode;
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

create or replace function public.join_pair(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare p public.pairs;
begin
  -- Pairing is rare; serializing it is what keeps "one pair per user" true
  -- (the two unique indexes cannot see across user_a and user_b).
  lock table public.pairs in share row exclusive mode;
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if public.my_pair_id() is not null then raise exception 'already_paired'; end if;
  select * into p from pairs where invite_code = trim(p_code) and user_b is null for update;
  if not found then raise exception 'invalid_code'; end if;
  if p.user_a = auth.uid() then raise exception 'own_code'; end if;
  delete from pairs where user_a = auth.uid() and user_b is null;
  update pairs set user_b = auth.uid() where id = p.id;
  return p.id;
end $$;
