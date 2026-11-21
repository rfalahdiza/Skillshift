// Midtrans Snap client — SANDBOX ONLY in this prototype.
// Docs: Snap create transaction, GET /v2/{order_id}/status, HTTP notification.

const SNAP_SANDBOX = "https://app.sandbox.midtrans.com/snap/v1/transactions";
const API_SANDBOX = "https://api.sandbox.midtrans.com";

export type PayMethod = "qris" | "va";

/** Snap `enabled_payments` per method shown on L12. */
export const ENABLED_PAYMENTS: Record<PayMethod, string[]> = {
  qris: ["other_qris"],
  va: ["bca_va", "bni_va", "bri_va", "echannel"],
};

/** Our payment states (public.payment_status). */
export type OurStatus = "pending" | "held" | "expired" | "failed" | "refunded";

/**
 * Midtrans transaction_status (+ fraud_status) → our payment status.
 * Paid money is "held" by the platform until both sides confirm attendance.
 */
export function mapStatus(
  transactionStatus: string,
  fraudStatus?: string | null,
): OurStatus {
  switch (transactionStatus) {
    case "settlement":
      return "held";
    case "capture":
      return fraudStatus === "accept" || !fraudStatus ? "held" : "pending";
    case "pending":
    case "authorize":
      return "pending";
    case "expire":
      return "expired";
    case "cancel":
    case "deny":
    case "failure":
      return "failed";
    case "refund":
    case "partial_refund":
    case "chargeback":
    case "partial_chargeback":
      return "refunded";
    default:
      return "pending";
  }
}

/** Which transitions we accept, so late or replayed notifications are safe. */
export function canTransition(from: string, to: OurStatus): boolean {
  if (from === to) return false;
  switch (from) {
    case "pending":
      return true;
    case "held":
      return to === "refunded"; // e.g. sandbox refund
    case "expired":
    case "failed":
      return to === "held"; // late settlement after an expiry race
    default:
      return false; // released / refunded are final
  }
}

/** order_id: max 50 chars, [A-Za-z0-9-_~.] only. */
export function makeOrderId(bookingId: string, now = Date.now()): string {
  return `SS-${bookingId.slice(0, 8)}-${now.toString(36)}`;
}

/** gross = price/hour × minutes / 60, whole rupiah. */
export function grossFor(pricePerHour: number, minutes: number): number {
  return Math.round((pricePerHour * minutes) / 60);
}

async function sha512Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    "SHA-512",
    new TextEncoder().encode(text),
  );
  return [...new Uint8Array(buf)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** SHA512(order_id + status_code + gross_amount + ServerKey). */
export async function signatureFor(
  orderId: string,
  statusCode: string,
  grossAmount: string,
  serverKey: string,
): Promise<string> {
  return await sha512Hex(orderId + statusCode + grossAmount + serverKey);
}

export async function verifySignature(
  n: {
    order_id?: string;
    status_code?: string;
    gross_amount?: string;
    signature_key?: string;
  },
  serverKey: string,
): Promise<boolean> {
  if (!n.order_id || !n.status_code || !n.gross_amount || !n.signature_key) {
    return false;
  }
  const expected = await signatureFor(
    n.order_id,
    n.status_code,
    n.gross_amount,
    serverKey,
  );
  // Constant-time-ish compare.
  if (expected.length !== n.signature_key.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ n.signature_key.charCodeAt(i);
  }
  return diff === 0;
}

export function serverKey(): string {
  if (Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true") {
    // Hard stop: this prototype must never move real money.
    throw new Error("Production Midtrans is disabled in this prototype.");
  }
  const key = Deno.env.get("MIDTRANS_SERVER_KEY") ?? "";
  if (!key.startsWith("SB-")) {
    throw new Error("MIDTRANS_SERVER_KEY must be a sandbox key (SB-...).");
  }
  return key;
}

function authHeader(key: string): string {
  return "Basic " + btoa(`${key}:`);
}

export async function createSnapTransaction(opts: {
  orderId: string;
  gross: number;
  itemName: string;
  method: PayMethod;
  expiryMinutes: number;
}): Promise<{ token: string; redirect_url: string }> {
  const key = serverKey();
  const res = await fetch(SNAP_SANDBOX, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: authHeader(key),
    },
    body: JSON.stringify({
      transaction_details: { order_id: opts.orderId, gross_amount: opts.gross },
      // No customer name or email: data minimisation.
      item_details: [{
        id: "session",
        price: opts.gross,
        quantity: 1,
        name: opts.itemName.slice(0, 50),
      }],
      enabled_payments: ENABLED_PAYMENTS[opts.method],
      expiry: { unit: "minutes", duration: opts.expiryMinutes },
    }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.redirect_url) {
    console.warn(`midtrans snap HTTP ${res.status}`, data?.error_messages);
    throw new Error("snap_failed");
  }
  return data;
}

export type MidtransStatus = {
  status_code?: string;
  transaction_status?: string;
  fraud_status?: string;
  gross_amount?: string;
  order_id?: string;
};

/** GET status; null when Midtrans has no transaction yet (404). */
export async function getStatus(
  orderId: string,
): Promise<MidtransStatus | null> {
  const key = serverKey();
  const res = await fetch(
    `${API_SANDBOX}/v2/${encodeURIComponent(orderId)}/status`,
    {
      headers: { Accept: "application/json", Authorization: authHeader(key) },
    },
  );
  const data = await res.json().catch(() => null);
  // Snap: 404 until the customer picks a payment method.
  if (!data || data.status_code === "404") return null;
  return data;
}
