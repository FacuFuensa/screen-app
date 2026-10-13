import type { SupabaseClient } from "npm:@supabase/supabase-js@2.117.3";
import { sendPush } from "./apns.ts";
import {
  answeredRequestPayload, type ApnsPayload, eventPayload, type EventRow, type GroupRow,
  pendingRequestPayload, type RequestRow,
} from "./payloads.ts";

export type Result = { sent: boolean; reason?: string };
type Pair = { id: string; user_a: string; user_b: string };

async function pairOf(admin: SupabaseClient, id: string): Promise<Pair> {
  const { data, error } = await admin.from("pairs").select("id,user_a,user_b").eq("id", id).single();
  if (error) throw error;
  return data as Pair;
}
async function nameOf(admin: SupabaseClient, id: string): Promise<string> {
  const { data } = await admin.from("profiles").select("display_name").eq("id", id).single();
  return (data as { display_name: string } | null)?.display_name ?? "Tu pareja";
}
async function groupOf(admin: SupabaseClient, id: string | null): Promise<GroupRow | null> {
  if (!id) return null;
  const { data } = await admin.from("limit_groups")
    .select("name,app_count,daily_minutes,window_start,window_end").eq("id", id).maybeSingle();
  return data as GroupRow | null;
}
const other = (p: Pair, u: string) => (u === p.user_a ? p.user_b : p.user_a);
const isMember = (p: Pair, u: string) => u === p.user_a || u === p.user_b;

async function push(admin: SupabaseClient, to: string, payload: ApnsPayload | null): Promise<Result> {
  if (!payload) return { sent: false, reason: "nothing_to_send" };
  const { data } = await admin.from("profiles").select("apns_token").eq("id", to).single();
  const token = (data as { apns_token: string | null } | null)?.apns_token;
  if (!token) return { sent: false, reason: "no_token" };
  const res = await sendPush(token, payload);
  if (res.status === 410 || res.reason === "BadDeviceToken") {
    await admin.from("profiles").update({ apns_token: null }).eq("id", to);
  }
  return { sent: res.ok, reason: res.reason };
}

export async function deliverRequest(admin: SupabaseClient, requestId: string, callerId: string): Promise<Result> {
  const { data, error } = await admin.from("requests").select("*").eq("id", requestId).maybeSingle();
  if (error || !data) return { sent: false, reason: "not_found" };
  const r = data as RequestRow & { pair_id: string };
  const pair = await pairOf(admin, r.pair_id);
  if (!isMember(pair, callerId)) return { sent: false, reason: "forbidden" };
  const partner = other(pair, r.from_user);
  const group = await groupOf(admin, r.group_id);
  if (r.status === "pending") {
    return push(admin, partner, pendingRequestPayload(r, group, await nameOf(admin, r.from_user)));
  }
  return push(admin, r.from_user, answeredRequestPayload(r, group?.name ?? null, await nameOf(admin, partner)));
}

export async function deliverEvent(admin: SupabaseClient, eventId: string, callerId: string | null): Promise<Result> {
  const { data, error } = await admin.from("events").select("*").eq("id", eventId).maybeSingle();
  if (error || !data) return { sent: false, reason: "not_found" };
  const ev = data as EventRow & { pair_id: string };
  const pair = await pairOf(admin, ev.pair_id);
  if (callerId && !isMember(pair, callerId)) return { sent: false, reason: "forbidden" };
  const group = await groupOf(admin, ev.group_id);
  return push(admin, other(pair, ev.actor), eventPayload(ev, await nameOf(admin, ev.actor), group?.name ?? null));
}
