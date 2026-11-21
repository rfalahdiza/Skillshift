// Applies a Midtrans status to our payment + booking rows. Idempotent:
// safe for duplicate, late and out-of-order notifications.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  canTransition,
  getStatus,
  mapStatus,
  type OurStatus,
} from "./midtrans.ts";

export type PaymentRow = {
  id: string;
  booking_id: string;
  status: string;
  gross: number;
  midtrans_order_id: string | null;
  expires_at: string | null;
};

/** Ask Midtrans for the truth and update our rows. Returns the new status. */
export async function syncPayment(
  db: SupabaseClient,
  payment: PaymentRow,
): Promise<string> {
  if (!payment.midtrans_order_id) return payment.status;
  if (
    payment.status !== "pending" && payment.status !== "expired" &&
    payment.status !== "failed" && payment.status !== "held"
  ) {
    return payment.status; // released / refunded: final
  }

  const st = await getStatus(payment.midtrans_order_id);
  let next: OurStatus;
  if (st?.transaction_status) {
    // Never trust an amount that does not match what we charged.
    const amount = Math.round(Number(st.gross_amount ?? "0"));
    if (amount && amount !== payment.gross) {
      console.error(`amount mismatch for ${payment.midtrans_order_id}`);
      return payment.status;
    }
    next = mapStatus(st.transaction_status, st.fraud_status);
  } else {
    // No transaction at Midtrans yet: expire it ourselves after the window.
    const expired = payment.expires_at &&
      new Date(payment.expires_at).getTime() < Date.now();
    next = expired ? "expired" : "pending";
  }

  if (!canTransition(payment.status, next)) return payment.status;

  const patch: Record<string, unknown> = {
    status: next,
    midtrans_status: st?.transaction_status ?? null,
  };
  if (next === "held") patch.paid_at = new Date().toISOString();
  const { error } = await db.from("payments")
    .update(patch)
    .eq("id", payment.id)
    .eq("status", payment.status); // optimistic: only from the state we read
  if (error) throw error;

  // Unpaid booking is cancelled; a late payment re-opens it as a request.
  if (next === "expired" || next === "failed") {
    await db.from("bookings").update({ status: "cancelled" })
      .eq("id", payment.booking_id).eq("status", "requested");
  } else if (next === "held" && payment.status !== "pending") {
    await db.from("bookings").update({ status: "requested" })
      .eq("id", payment.booking_id).eq("status", "cancelled");
  }
  return next;
}
