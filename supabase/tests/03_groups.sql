begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

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

select ok(public.is_loosening(30, 45, null, null, null, null, false), 'más minutos afloja');
select ok(not public.is_loosening(30, 20, null, null, null, null, false), 'menos minutos endurece');
select ok(public.is_loosening(null, null, 1380, 420, 1380, 360, false), 'terminar el bloqueo antes afloja');
select ok(not public.is_loosening(null, null, 1380, 420, 1320, 480, false), 'agrandar el bloqueo endurece');
select ok(public.is_loosening(30, 30, 1380, 420, null, null, false), 'sacar el horario afloja');

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select is(public.save_group('20000000-0000-0000-0000-000000000001', 'Redes', 2, 30), 'created', 'A crea un grupo');
select is(public.save_group('20000000-0000-0000-0000-000000000001', 'Redes', 2, 20), 'updated', 'bajar minutos se aplica');
select is((select count(*)::int from public.events where kind = 'limit_tightened'), 1, 'endurecer deja un evento');
select is(public.save_group('20000000-0000-0000-0000-000000000001', 'Social', 2, 20), 'updated', 'renombrar es libre');
select throws_ok($$select public.save_group('20000000-0000-0000-0000-000000000001', 'Social', 2, 40)$$,
  'P0001', 'loosening_requires_approval', 'subir minutos con pareja necesita aprobación');
select throws_ok($$select public.save_group('20000000-0000-0000-0000-000000000001', 'Social', 1, 20)$$,
  'P0001', 'loosening_requires_approval', 'sacar apps necesita aprobación aunque no lo diga el cliente');
select lives_ok($$select public.save_group(gen_random_uuid(), 'G' || i, 1, 10) from generate_series(1, 4) i$$, 'hasta 5 grupos');
select throws_ok($$select public.save_group(gen_random_uuid(), 'G6', 1, 10)$$, 'P0001', 'too_many_groups', 'el sexto grupo se rechaza');
select throws_ok($$select public.delete_group('20000000-0000-0000-0000-000000000001')$$,
  'P0001', 'loosening_requires_approval', 'borrar con pareja necesita aprobación');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}';
select is(public.save_group('20000000-0000-0000-0000-00000000000c', 'Juegos', 1, 60), 'created', 'C sin pareja crea');
select is(public.save_group('20000000-0000-0000-0000-00000000000c', 'Juegos', 1, 120), 'updated', 'sin pareja se puede aflojar');
select lives_ok($$select public.delete_group('20000000-0000-0000-0000-00000000000c')$$, 'sin pareja se puede borrar');

reset role;
select * from finish();
rollback;
