export type Kind = "extra_time" | "loosen_limit";
export interface Proposed {
  name?: string; app_count?: number; daily_minutes?: number | null;
  window_start?: number | null; window_end?: number | null; delete?: boolean;
}
export interface RequestRow {
  id: string; kind: Kind; status: "pending" | "granted" | "denied" | "superseded" | "cancelled";
  minutes: number | null; granted_minutes: number | null; message: string | null;
  payload: Proposed | null; from_user: string; group_id: string | null;
}
export interface GroupRow {
  name: string; app_count: number; daily_minutes: number | null;
  window_start: number | null; window_end: number | null;
}
export interface EventRow { id: string; kind: string; actor: string; group_id: string | null; data: Record<string, unknown> }
export interface ApnsPayload {
  aps: { alert: { title: string; body: string }; sound: "default"; category?: string; "content-available"?: 1 };
  type: "request" | "granted" | "answered" | "event";
  request_id?: string;
  event_id?: string;
}

export function clock(m: number): string {
  return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
}
const windowText = (s: number | null, e: number | null) => (s === null || e === null ? "sin horario" : `${clock(s)}–${clock(e)}`);
const minutesText = (n: number | null) => (n === null ? "sin límite" : `${n} min`);

export function describeLoosen(current: GroupRow, p: Proposed): string {
  if (p.delete) return `Borrar el grupo ${current.name}`;
  const parts: string[] = [];
  const newMin = p.daily_minutes ?? null;
  if (newMin !== current.daily_minutes) parts.push(`${minutesText(current.daily_minutes)} → ${minutesText(newMin)}`);
  const ns = p.window_start ?? null, ne = p.window_end ?? null;
  if (ns !== current.window_start || ne !== current.window_end) {
    parts.push(`bloqueo ${windowText(current.window_start, current.window_end)} → ${windowText(ns, ne)}`);
  }
  if (p.app_count !== undefined && p.app_count !== current.app_count) parts.push(`${current.app_count} → ${p.app_count} apps`);
  if (parts.length === 0) parts.push("cambia qué apps entran");
  return `${current.name}: ${parts.join(" · ")}`;
}

export function pendingRequestPayload(r: RequestRow, group: GroupRow | null, fromName: string): ApnsPayload {
  const groupName = group?.name ?? "un grupo";
  if (r.kind === "extra_time") {
    return {
      aps: {
        alert: { title: `${fromName} pide ${r.minutes} min`, body: r.message ? `${groupName}: “${r.message}”` : groupName },
        sound: "default",
        category: `EXTRA_TIME_REQUEST_${r.minutes}`,
      },
      type: "request",
      request_id: r.id,
    };
  }
  return {
    aps: {
      alert: { title: `${fromName} quiere aflojar un límite`, body: group && r.payload ? describeLoosen(group, r.payload) : groupName },
      sound: "default",
      category: "LOOSEN_REQUEST",
    },
    type: "request",
    request_id: r.id,
  };
}

export function answeredRequestPayload(r: RequestRow, groupName: string | null, partnerName: string): ApnsPayload | null {
  if (r.status === "pending" || r.status === "superseded" || r.status === "cancelled") return null;
  const g = groupName ?? "tu grupo";
  if (r.status === "denied") {
    const body = r.kind === "extra_time" ? `Sin minutos extra en ${g}` : `Sigue el límite actual de ${g}`;
    return { aps: { alert: { title: `${partnerName} dijo que no`, body }, sound: "default" }, type: "answered", request_id: r.id };
  }
  const title = r.kind === "extra_time" ? `Te dieron ${r.granted_minutes} min` : `${partnerName} aprobó tu cambio`;
  const body = r.kind === "extra_time" ? `${partnerName} te dio tiempo en ${g}` : g;
  return { aps: { alert: { title, body }, sound: "default", "content-available": 1 }, type: "granted", request_id: r.id };
}

const EVENT_PUSH: Record<string, (actor: string, group: string) => { title: string; body: string }> = {
  limit_reached: (a, g) => ({ title: `${a} llegó al límite`, body: g }),
  wildcard_used: (a, g) => ({ title: `${a} usó su comodín`, body: `5 min en ${g}` }),
  auth_revoked: (a) => ({ title: `${a} desactivó los permisos de Screen`, body: "Sus límites dejaron de aplicarse" }),
  silent_24h: (a) => ({ title: `${a} no reporta hace un día`, body: "Puede haber borrado la app o tener el celu apagado" }),
};

export function eventPayload(ev: EventRow, actorName: string, groupName: string | null): ApnsPayload | null {
  const f = EVENT_PUSH[ev.kind];
  if (!f) return null;
  return { aps: { alert: f(actorName, groupName ?? "un grupo"), sound: "default" }, type: "event", event_id: ev.id };
}
