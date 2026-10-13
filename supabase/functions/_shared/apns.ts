import { importPKCS8, SignJWT } from "npm:jose@6.2.12";
import type { ApnsPayload } from "./payloads.ts";

let cached: { jwt: string; at: number } | null = null;

// APNs provider tokens are valid for an hour; refresh a bit earlier.
async function providerToken(): Promise<string> {
  if (cached && Date.now() - cached.at < 50 * 60 * 1000) return cached.jwt;
  const key = await importPKCS8(Deno.env.get("APNS_KEY_P8")!.replace(/\\n/g, "\n"), "ES256");
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: Deno.env.get("APNS_KEY_ID")! })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt()
    .sign(key);
  cached = { jwt, at: Date.now() };
  return jwt;
}

export async function sendPush(deviceToken: string, payload: ApnsPayload): Promise<{ ok: boolean; status: number; reason?: string }> {
  const host = Deno.env.get("APNS_HOST") ?? "api.sandbox.push.apple.com";
  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken()}`,
      "apns-topic": Deno.env.get("APNS_TOPIC") ?? "com.facufuensa.screen",
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (res.ok) return { ok: true, status: res.status };
  const body = await res.json().catch(() => ({}));
  return { ok: false, status: res.status, reason: (body as { reason?: string }).reason };
}
