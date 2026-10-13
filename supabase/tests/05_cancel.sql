begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.dev'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.dev');
insert into public.profiles (id, display_name) values
  ('00000000-0000-0000-0000-00000000000a', 'Ana'),
  ('00000000-0000-0000-0000-00000000000b', 'Beto');
insert into public.pairs (user_a, user_b, invite_code) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', '111111');
insert into public.limit_groups (id, owner, name, app_count, daily_minutes) values
  ('30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'Redes', 2, 30);

set local role authenticated;
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select isnt(set_config('test.r1', public.request_extra_time('30000000-0000-0000-0000-000000000001', 15)::text, true), null, 'A pide 15 min');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select throws_ok($$select public.cancel_request(current_setting('test.r1')::uuid)$$, 'P0001', 'not_found', 'B no puede cancelar un pedido de A');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select lives_ok($$select public.cancel_request(current_setting('test.r1')::uuid)$$, 'A cancela su pedido');
select is((select status from public.requests where id = current_setting('test.r1')::uuid), 'cancelled', 'queda cancelado');
select throws_ok($$select public.cancel_request(current_setting('test.r1')::uuid)$$, 'P0001', 'not_pending', 'no se cancela dos veces');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select throws_ok($$select public.answer_request(current_setting('test.r1')::uuid, true)$$, 'P0001', 'not_pending', 'un pedido cancelado no se puede aprobar');

-- Race: B answers first, then A tries to cancel.
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select set_config('test.r2', public.request_extra_time('30000000-0000-0000-0000-000000000001', 5)::text, true);
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select public.answer_request(current_setting('test.r2')::uuid, true);
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select throws_ok($$select public.cancel_request(current_setting('test.r2')::uuid)$$, 'P0001', 'not_pending', 'no se cancela uno ya respondido');

reset role;
select * from finish();
rollback;
