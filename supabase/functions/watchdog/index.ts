import { createClient } from "npm:@supabase/supabase-js@2.117.3";
import { deliverEvent } from "../_shared/deliver.ts";

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("CRON_SECRET")) {
    return new Response("unauthorized", { status: 401 });
  }
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await admin.rpc("watchdog_scan");
  if (error) return new Response(error.message, { status: 500 });
  const rows = (data ?? []) as { event_id: string }[];
  for (const row of rows) await deliverEvent(admin, row.event_id, null);
  return Response.json({ alerted: rows.length });
});
