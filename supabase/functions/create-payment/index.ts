// create-payment: L12 "Pay". Creates the paid booking (as the user, so RLS
// and the booking rules apply), then a Midtrans SANDBOX Snap transaction.
//
// POST { mentor_id, course_id, starts_at (ISO), place, method: "qris"|"va" }

import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  handler,
  HttpError,
  isUuid,
  json,
  requireUser,
  serviceClient,
} from "../_shared/http.ts";
import {
  createSnapTransaction,
  grossFor,
  makeOrderId,
  type PayMethod,
} from "../_shared/midtrans.ts";

const DURATION_MIN = 60; // paid sessions on L11 are 60 minutes
const EXPIRY_MIN = 15; // "Pay within 15:00"

Deno.serve(handler(async (req, body) => {
  const db = serviceClient();
  const userId = await requireUser(req, db);

  const { mentor_id, course_id, starts_at, place, method } = body;
  if (!isUuid(mentor_id) || !isUuid(course_id)) {
    throw new HttpError(400, "Pick a mentor and course.");
  }
  if (method !== "qris" && method !== "va") {
    throw new HttpError(400, "Pick QRIS or virtual account.");
  }
  if (typeof starts_at !== "string" || isNaN(Date.parse(starts_at))) {
    throw new HttpError(400, "Pick a time.");
  }
  if (typeof place !== "string" || !place.trim() || place.length > 120) {
    throw new HttpError(400, "Pick a place on campus.");
  }

  // Price comes from the database, never from the app.
  const { data: offer, error: offerErr } = await db
    .from("mentor_courses")
    .select("price_per_hour, course:courses(name)")
    .eq("mentor_id", mentor_id)
    .eq("course_id", course_id)
    .maybeSingle();
  if (offerErr) throw offerErr;
  if (!offer) {
    throw new HttpError(400, "This mentor is not verified for this course.");
  }

  const gross = grossFor(offer.price_per_hour, DURATION_MIN);
  const { data: split, error: splitErr } = await db
    .rpc("payment_split", { p_gross: gross })
    .single<{ platform_fee: number; mentor_net: number }>();
  if (splitErr || !split) throw splitErr ?? new Error("split failed");

  // Insert the booking AS THE USER so the bookings_insert_guard trigger and
  // RLS check it (own booking, future time, verified mentor).
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: req.headers.get("Authorization")! } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data: booking, error: bookingErr } = await asUser
    .from("bookings")
    .insert({
      learner_id: userId,
      mentor_id,
      course_id,
      starts_at: new Date(starts_at).toISOString(),
      duration_min: DURATION_MIN,
      place: place.trim(),
      is_free_trial: false,
    })
    .select("id")
    .single();
  if (bookingErr) {
    // Our triggers raise readable messages (P0001).
    throw new HttpError(
      400,
      bookingErr.code === "P0001"
        ? bookingErr.message
        : "Could not create the booking. Try another time.",
    );
  }

  const orderId = makeOrderId(booking.id);
  // deno-lint-ignore no-explicit-any
  const courseName = (offer.course as any)?.name ?? "Session";
  let snap: { token: string; redirect_url: string };
  try {
    snap = await createSnapTransaction({
      orderId,
      gross,
      itemName: `SkillShift ${courseName} 60 min`,
      method: method as PayMethod,
      expiryMinutes: EXPIRY_MIN,
    });
  } catch (e) {
    // Undo the booking so the slot is free again.
    await db.from("bookings").delete().eq("id", booking.id);
    if (e instanceof Error && e.message.includes("sandbox key")) {
      console.error(e.message);
    }
    throw new HttpError(
      502,
      "The payment service is not available right now. Try again later.",
    );
  }

  const expiresAt = new Date(Date.now() + EXPIRY_MIN * 60_000).toISOString();
  const { data: payment, error: payErr } = await db.from("payments").insert({
    booking_id: booking.id,
    gross,
    platform_fee: split.platform_fee,
    mentor_net: split.mentor_net,
    midtrans_order_id: orderId,
    snap_redirect_url: snap.redirect_url,
    method,
    status: "pending",
    is_sandbox: true,
    expires_at: expiresAt,
  }).select("id").single();
  if (payErr) throw payErr;

  return json({
    booking_id: booking.id,
    payment_id: payment.id,
    order_id: orderId,
    gross,
    redirect_url: snap.redirect_url,
    expires_at: expiresAt,
    is_sandbox: true,
  });
}));
