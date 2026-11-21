-- Phase 3: Midtrans sandbox payments.
-- Extra payment states for unpaid Snap transactions, plus the expiry time
-- shown on L13 ("Pay within 14:52").

alter type public.payment_status add value if not exists 'expired';
alter type public.payment_status add value if not exists 'failed';

alter table public.payments
  add column if not exists expires_at timestamptz,
  -- Last transaction_status seen from Midtrans (for debugging/reconciling).
  add column if not exists midtrans_status text;

comment on column public.payments.is_sandbox is
  'Always true: this prototype only talks to the Midtrans sandbox.';
