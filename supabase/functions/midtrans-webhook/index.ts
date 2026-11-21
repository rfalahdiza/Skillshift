// midtrans-webhook: Midtrans SANDBOX HTTP notification.
// Deployed with --no-verify-jwt (Midtrans cannot send a Supabase JWT), so
// every request is verified by signature_key and then re-checked with the
// Midtrans status API before anything changes.

import { corsHeaders, json, serviceClient } from "../_shared/http.ts";
import { serverKey, verifySignature } from "../_shared/midtrans.ts";
import { type PaymentRow, syncPayment } from "../_shared/payments.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  let n: Record<string, string>;
  try {
    n = await req.json();
  } catch {
    return json({ error: "Invalid JSON." }, 400);
  }

  try {
    if (!(await verifySignature(n, serverKey()))) {
      console.warn("midtrans-webhook: bad signature");
      return json({ error: "Invalid signature." }, 401);
    }

    const db = serviceClient();
    const { data: payment, error } = await db
      .from("payments")
      .select("id, booking_id, status, gross, midtrans_order_id, expires_at")
      .eq("midtrans_order_id", n.order_id)
      .maybeSingle<PaymentRow>();
    if (error) throw error;
    // Unknown order (e.g. Midtrans dashboard test): acknowledge, do nothing.
    if (!payment) return json({ ok: true, ignored: true });

    // Source of truth is GET status, not the notification body.
    const status = await syncPayment(db, payment);
    return json({ ok: true, status });
  } catch (e) {
    console.error(
      "midtrans-webhook failed",
      e instanceof Error ? e.message : e,
    );
    // 500 makes Midtrans retry later.
    return json({ error: "Temporary error." }, 500);
  }
});
