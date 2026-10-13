import { createClient } from "npm:@supabase/supabase-js@2.117.3";
import { deliverEvent, deliverRequest } from "../_shared/deliver.ts";

Deno.serve(async (req) => {
  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await caller.auth.getUser();
  if (!user) return new Response("unauthorized", { status: 401 });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const body = await req.json().catch(() => ({})) as { request_id?: string; event_id?: string };
  const result = body.request_id
    ? await deliverRequest(admin, body.request_id, user.id)
    : body.event_id
    ? await deliverEvent(admin, body.event_id, user.id)
    : { sent: false, reason: "bad_request" };
  return Response.json(result);
});
