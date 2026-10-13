begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.dev'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.dev'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.dev');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select lives_ok($$select public.ensure_profile('Ana')$$, 'A crea su perfil');
select matches(set_config('test.code', public.create_invite(), true), '^[0-9]{6}$', 'el código tiene 6 dígitos');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select lives_ok($$select public.ensure_profile('Beto')$$, 'B crea su perfil');
select lives_ok($$select public.join_pair(current_setting('test.code'))$$, 'B se une con el código');
select is((select count(*)::int from public.pairs where user_b is not null), 1, 'la pareja quedó completa');
select throws_ok($$select public.create_invite()$$, 'P0001', 'already_paired', 'B ya tiene pareja');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select lives_ok($$select public.ensure_profile('Caro')$$, 'C crea su perfil');
select throws_ok($$select public.join_pair(current_setting('test.code'))$$, 'P0001', 'invalid_code', 'un código usado no sirve');
select matches(set_config('test.code_c', public.create_invite(), true), '^[0-9]{6}$', 'C genera su código');
select throws_ok($$select public.join_pair(current_setting('test.code_c'))$$, 'P0001', 'own_code', 'no podés usar tu propio código');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select is(public.heartbeat('approved', 'tok-a'), null::uuid, 'heartbeat normal no genera evento');
select isnt(public.heartbeat('denied'), null::uuid, 'pasar de approved a denied genera un evento');

reset role;
update public.profiles set last_seen_at = now() - interval '25 hours'
  where id = '00000000-0000-0000-0000-00000000000b';
select is((select count(*)::int from public.watchdog_scan()), 1, 'B sin reportar 25 h dispara un aviso');
select is((select count(*)::int from public.watchdog_scan()), 0, 'el aviso no se repite');

select * from finish();
rollback;
