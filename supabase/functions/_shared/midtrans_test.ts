import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  canTransition,
  grossFor,
  makeOrderId,
  mapStatus,
  signatureFor,
  verifySignature,
} from "./midtrans.ts";

Deno.test("mapStatus: Midtrans states to our payment states", () => {
  assertEquals(mapStatus("settlement"), "held");
  assertEquals(mapStatus("capture", "accept"), "held");
  assertEquals(mapStatus("capture", "challenge"), "pending");
  assertEquals(mapStatus("pending"), "pending");
  assertEquals(mapStatus("expire"), "expired");
  for (const s of ["cancel", "deny", "failure"]) {
    assertEquals(mapStatus(s), "failed");
  }
  for (const s of ["refund", "partial_refund", "chargeback"]) {
    assertEquals(mapStatus(s), "refunded");
  }
  assertEquals(mapStatus("something_new"), "pending");
});

Deno.test("canTransition: replays and late notifications are safe", () => {
  assert(canTransition("pending", "held"));
  assert(canTransition("pending", "expired"));
  assert(!canTransition("held", "held")); // duplicate notification
  assert(!canTransition("held", "pending")); // out of order
  assert(!canTransition("held", "expired"));
  assert(canTransition("held", "refunded"));
  assert(canTransition("expired", "held")); // paid right at the deadline
  assert(!canTransition("released", "refunded")); // final
  assert(!canTransition("refunded", "held")); // final
});

Deno.test("order ids are short, unique per call and Midtrans-safe", () => {
  const a = makeOrderId("d0000000-0000-4000-8000-000000000001", 1_000);
  const b = makeOrderId("d0000000-0000-4000-8000-000000000001", 2_000);
  assert(a !== b);
  assert(a.length <= 50);
  assert(/^[A-Za-z0-9\-_~.]+$/.test(a));
});

Deno.test("grossFor: hourly price to whole rupiah", () => {
  assertEquals(grossFor(25000, 60), 25000);
  assertEquals(grossFor(25000, 30), 12500);
  assertEquals(grossFor(27500, 30), 13750);
});

Deno.test("signature: SHA512(order_id + status_code + gross + key)", async () => {
  const key = "SB-Mid-server-TEST";
  const sig = await signatureFor("SS-abc-1", "200", "25000.00", key);
  assertEquals(sig.length, 128);
  const n = {
    order_id: "SS-abc-1",
    status_code: "200",
    gross_amount: "25000.00",
    signature_key: sig,
  };
  assert(await verifySignature(n, key));
  assert(!(await verifySignature({ ...n, gross_amount: "1.00" }, key)));
  assert(!(await verifySignature({ ...n, signature_key: "x" }, key)));
  assert(!(await verifySignature({ order_id: "SS-abc-1" }, key)));
});
