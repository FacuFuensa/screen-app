import { assertEquals } from "jsr:@std/assert@1";
import {
  answeredRequestPayload, describeLoosen, eventPayload, pendingRequestPayload,
  type GroupRow, type RequestRow,
} from "./payloads.ts";

const group: GroupRow = { name: "Redes", app_count: 2, daily_minutes: 30, window_start: null, window_end: null };
const base: RequestRow = {
  id: "r1", kind: "extra_time", status: "pending", minutes: 15, granted_minutes: null,
  message: "es por laburo", payload: null, from_user: "a", group_id: "g1",
};

Deno.test("pending extra time names minutes, group and message", () => {
  const p = pendingRequestPayload(base, group, "Ana");
  assertEquals(p.aps.alert, { title: "Ana pide 15 min", body: "Redes: “es por laburo”" });
  assertEquals(p.aps.category, "EXTRA_TIME_REQUEST_15");
  assertEquals(p.request_id, "r1");
});

Deno.test("loosen diff shows before and after", () => {
  assertEquals(
    describeLoosen(group, { name: "Redes", app_count: 2, daily_minutes: 60, window_start: 1380, window_end: 420 }),
    "Redes: 30 min → 60 min · bloqueo sin horario → 23:00–07:00",
  );
});

Deno.test("swapping apps at the same count is still explained", () => {
  assertEquals(
    describeLoosen(group, { name: "Redes", app_count: 2, daily_minutes: 30, window_start: null, window_end: null }),
    "Redes: cambia qué apps entran",
  );
});

Deno.test("loosen delete", () => {
  assertEquals(describeLoosen(group, { delete: true }), "Borrar el grupo Redes");
});

Deno.test("granted extra time wakes the requester's app", () => {
  const p = answeredRequestPayload({ ...base, status: "granted", granted_minutes: 20 }, "Redes", "Beto")!;
  assertEquals(p.aps.alert.title, "Te dieron 20 min");
  assertEquals(p.aps["content-available"], 1);
  assertEquals(p.type, "granted");
});

Deno.test("superseded requests send nothing", () => {
  assertEquals(answeredRequestPayload({ ...base, status: "superseded" }, "Redes", "Beto"), null);
});

Deno.test("only some events push", () => {
  assertEquals(eventPayload({ id: "e1", kind: "threshold_80", actor: "a", group_id: null, data: {} }, "Ana", null), null);
  assertEquals(
    eventPayload({ id: "e2", kind: "auth_revoked", actor: "a", group_id: null, data: {} }, "Ana", null)!.aps.alert.title,
    "Ana desactivó los permisos de Screen",
  );
});
