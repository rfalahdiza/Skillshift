// payment-status: L13 "Check payment status". Asks Midtrans (sandbox) for
// the real status and updates our rows. Works even before the webhook URL
// is configured.
//
// POST { booking_id }

import {
  handler,
  HttpError,
  isUuid,
  json,
  requireUser,
  serviceClient,
} from "../_shared/http.ts";
import { type PaymentRow, syncPayment } from "../_shared/payments.ts";

Deno.serve(handler(async (req, body) => {
  const db = serviceClient();
  const userId = await requireUser(req, db);
  if (!isUuid(body.booking_id)) throw new HttpError(400, "Missing booking.");

  const { data: booking, error } = await db
    .from("bookings")
    .select("id, learner_id, mentor_id, status")
    .eq("id", body.booking_id)
    .maybeSingle();
  if (error) throw error;
  if (!booking || ![booking.learner_id, booking.mentor_id].includes(userId)) {
    throw new HttpError(404, "Booking not found.");
  }

  const { data: payment, error: payErr } = await db
    .from("payments")
    .select("id, booking_id, status, gross, midtrans_order_id, expires_at")
    .eq("booking_id", booking.id)
    .maybeSingle<PaymentRow>();
  if (payErr) throw payErr;
  if (!payment) {
    return json({ payment_status: null, booking_status: booking.status });
  }

  const status = await syncPayment(db, payment);
  const { data: fresh } = await db.from("bookings").select("status")
    .eq("id", booking.id).single();
  return json({ payment_status: status, booking_status: fresh?.status });
}));
