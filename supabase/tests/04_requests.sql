begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

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
-- A asks
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select isnt(set_config('test.r1', public.request_extra_time('30000000-0000-0000-0000-000000000001', 15, 'laburo')::text, true), null, 'A pide 15 min');
select isnt(set_config('test.r2', public.request_extra_time('30000000-0000-0000-0000-000000000001', 30)::text, true), null, 'A vuelve a pedir');
select is((select status from public.requests where id = current_setting('test.r1')::uuid), 'superseded', 'el pedido viejo queda reemplazado');
select throws_ok($$select public.request_extra_time('30000000-0000-0000-0000-000000000001', 7)$$, 'P0001', 'invalid_minutes', 'solo 5, 15 o 30');
select throws_ok($$select public.answer_request(current_setting('test.r2')::uuid, true)$$, 'P0001', 'cannot_answer_own', 'no te podés aprobar a vos mismo');

-- B answers
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select lives_ok($$select public.answer_request(current_setting('test.r2')::uuid, true, 20)$$, 'B da 20 min');
select is((select granted_minutes from public.requests where id = current_setting('test.r2')::uuid), 20, 'quedan 20 min otorgados');
select throws_ok($$select public.answer_request(current_setting('test.r2')::uuid, false)$$, 'P0001', 'not_pending', 'no se responde dos veces');
select lives_ok($$select public.mark_applied(current_setting('test.r2')::uuid)$$, 'B intenta marcar aplicado');
select is((select applied_at from public.requests where id = current_setting('test.r2')::uuid), null, 'solo quien pidió puede marcar aplicado');

set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select lives_ok($$select public.mark_applied(current_setting('test.r2')::uuid)$$, 'A marca aplicado');
select isnt(set_config('test.r3', public.request_extra_time('30000000-0000-0000-0000-000000000001', 5)::text, true), null, 'A pide 5 min');

reset role;
update public.requests set expires_at = now() - interval '1 minute' where id = current_setting('test.r3')::uuid;
set local role authenticated;
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select throws_ok($$select public.answer_request(current_setting('test.r3')::uuid, true)$$, 'P0001', 'request_expired', 'un pedido vencido no se puede aprobar');

-- Loosen: raise to 60 min
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select isnt(set_config('test.r4', public.request_loosen('30000000-0000-0000-0000-000000000001',
  '{"name":"Redes","app_count":2,"daily_minutes":60,"window_start":null,"window_end":null}')::text, true), null, 'A pide subir a 60');
select throws_ok($$select public.request_loosen('30000000-0000-0000-0000-000000000001', '{"name":"x"}')$$, 'P0001', 'invalid_payload', 'el payload va completo');
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select lives_ok($$select public.answer_request(current_setting('test.r4')::uuid, true)$$, 'B aprueba');
select is((select daily_minutes from public.limit_groups where id = '30000000-0000-0000-0000-000000000001'), 60, 'el límite pasó a 60');

-- Loosen: delete the group
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select set_config('test.r5', public.request_loosen('30000000-0000-0000-0000-000000000001', '{"delete":true}')::text, true);
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}';
select lives_ok($$select public.answer_request(current_setting('test.r5')::uuid, true)$$, 'B aprueba borrar');

-- Device events
set local "request.jwt.claims" to '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}';
select isnt(public.log_event('limit_reached', null, '{}', 'limit_reached.g.2026-10-12'), null, 'A registra un evento');
select is(public.log_event('limit_reached', null, '{}', 'limit_reached.g.2026-10-12'), null, 'el mismo client_id no se duplica');
select throws_ok($$select public.log_event('auth_revoked')$$, 'P0001', 'invalid_kind', 'el cliente no inventa eventos del servidor');

reset role;
select * from finish();
rollback;
