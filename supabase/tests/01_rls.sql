begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.dev'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.dev'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.dev');
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-00000000000a', 'Ana'),
  ('00000000-0000-0000-0000-00000000000b', 'Beto'),
  ('00000000-0000-0000-0000-00000000000c', 'Caro');
insert into public.pairs (user_a, user_b, invite_code) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', '111111');
insert into public.limit_groups (id, owner, name, app_count, daily_minutes) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000a', 'Redes', 2, 30),
  ('10000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-00000000000c', 'Juegos', 1, 60);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select is((select count(*)::int from public.limit_groups), 1, 'B ve solo los grupos de su pareja');
select is((select count(*)::int from public.profiles), 2, 'B ve su perfil y el de su pareja');
select throws_ok(
  $$insert into public.limit_groups (id, owner, name, app_count) values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000b', 'X', 1)$$,
  '42501', null, 'escribir directo en limit_groups está prohibido');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select is((select count(*)::int from public.profiles), 1, 'C sin pareja solo se ve a sí misma');
select is((select count(*)::int from public.pairs), 0, 'C no ve parejas ajenas');

reset role;
set local role anon;
select throws_ok($$select * from public.limit_groups$$, '42501', null, 'anon no puede leer nada');
reset role;

select * from finish();
rollback;
