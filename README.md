# SkillShift

Peer tutoring for Universitas Brawijaya (UB) students. First-year learners get matched with verified seniors who are free in the same class gaps, and meet on campus. The first 30-minute session with each mentor is free. Later sessions are paid with QRIS or a virtual account, held by the platform and released to the mentor only after both sides confirm attendance.

> **Prototype for STACK 2026.** Payments use the **Midtrans sandbox** (test transactions only). **Mentor payouts are simulated** (database records, no money moves). Seed data is **fake test data**. The app labels all three in the UI.

## Status

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Theme and tokens, shared widgets, routing and role guards, adaptive shell, Supabase schema, RLS, seed | **Done** |
| 2 | Learner core: L01–L11, matching Edge Function, Gemini tags and reasons | **Done** (free-trial booking; paid checkout is Phase 3) |
| 3 | Checkout, QRIS (Midtrans sandbox), booking confirmed, attendance: L12–L15 | **Done** |
| 4 | Mentor: M01–M05 | **Done** |
| 5 | Admin: AD01–AD04, A01–A03 | **Done** |
| 6 | Tablet two-pane polish: T01–T06 | Planned |

Screens that are not built yet show a plain "Planned · Phase N" placeholder so nothing planned looks finished.

## Requirements

- Flutter 3.47 (stable), Dart 3.13
- Android SDK (Android first). Flutter web stays buildable for the admin screens.
- For the backend: [Supabase CLI](https://supabase.com/docs/guides/cli) 3.x, [Deno](https://deno.com) 2.x, and Docker Desktop to run Supabase locally.

## Setup

```bash
flutter pub get
cp .env.example .env          # then fill in the values
flutter run --dart-define-from-file=.env
```

VS Code: use the **SkillShift (debug)** launch configuration (`.vscode/launch.json`), which passes the same flag.

Without a `.env` the app still runs: splash, onboarding, then the sign-in screen with a "Supabase is not configured" notice. In **debug builds** the sign-in screen also has **Dev tools**:

- **Demo sign-in** with the seeded test accounts (needs `DEMO_PASSWORD` and a seeded database), so a demo does not depend on email delivery.
- **Preview learner / mentor / admin**: the whole app offline with fake sample data, marked with a "Dev preview" strip. The learner flow (timetable, quiz, matches, profile, free-trial booking) works end to end here.
- **Component gallery**: every shared widget next to the Figma design system.

### Local Supabase

Needs Docker Desktop (which needs WSL 2 on Windows).

```bash
supabase start                      # prints the local URL and anon key
dart run tool/gen_demo_seed.dart    # optional: demo password for seed accounts
supabase db reset                   # applies migrations + seed.sql (+ seed.local.sql)
cp supabase/functions/.env.example supabase/functions/.env   # add GEMINI_API_KEY
supabase functions serve --env-file supabase/functions/.env
```

Local sign-in emails land in Inbucket/Mailpit (URL printed by `supabase start`).

From the Android emulator the local API is at `http://10.0.2.2:54321`.

### Remote Supabase

Do not run these against the shared project without agreeing first.

```bash
supabase link --project-ref <ref>
supabase db push
supabase secrets set --env-file supabase/functions/.env
supabase functions deploy match-mentors tag-preferences create-payment payment-status --use-api
supabase functions deploy midtrans-webhook --use-api --no-verify-jwt
```

**Midtrans sandbox (one-time):** create a free account at the Midtrans sandbox dashboard, copy the **sandbox Server Key** (`SB-Mid-server-…`) into the Supabase secret `MIDTRANS_SERVER_KEY`, and set the Payment Notification URL to `https://<project-ref>.supabase.co/functions/v1/midtrans-webhook`. The functions refuse any key that is not a sandbox key, and refuse to run if `MIDTRANS_IS_PRODUCTION=true`.

**Email template (remote, one-time):** in the Supabase dashboard, under Authentication → Emails, paste `supabase/templates/otp_code.html` into both **Magic Link** and **Confirm signup**. It contains `{{ .Token }}`, so users get the 6-digit code that L04 expects instead of a link. The free built-in email sender is rate-limited (a few emails per hour); use the demo sign-in for recordings or add your own SMTP.

## Environment variables

**App (`.env`, gitignored, passed with `--dart-define-from-file`).** Public values only.

| Name | Purpose |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Anon or `sb_publishable_…` key (public; data is protected by RLS) |
| `DEMO_PASSWORD` | Password for seeded test accounts, debug builds only (at least 12 characters) |

**Edge Functions (`supabase/functions/.env`, gitignored, set as Supabase secrets).**

| Name | Purpose |
| --- | --- |
| `GEMINI_API_KEY` | Gemini free tier, called only from Edge Functions |
| `GEMINI_MODEL` | Model name, configurable (default `gemini-3.8-flash`; `gemini-3.5-flash-lite` is a faster alternative) |
| `MIDTRANS_SERVER_KEY` | Midtrans **sandbox** server key |
| `MIDTRANS_IS_PRODUCTION` | Always `false` in this prototype |

`.env` files are never committed. `.env.example` files list the names only.

## Architecture

```
lib/
  core/
    auth/        AppSession, SessionController (Supabase auth + profile, debug preview)
    config/      Env (compile-time values), AppDefaults (display defaults)
    layout/      AdaptiveShell (bottom nav < 900 px, 248 px sidebar ≥ 900 px), nav items per role
    router/      go_router setup, pure role-guard redirect (unit-tested), route names
    supabase/    client init and provider
    theme/       color, type, spacing, radius tokens from Figma; Lucide icon map
    utils/       Rupiah, NIM masking, UB email check, fee split, WIB time, free gaps
  data/          models, SkillShiftRepository (Supabase + offline sample), Riverpod providers
  features/      onboarding, auth (L03–L05), learner (L06–L15), mentor (M01–M05),
                 admin (AD01–AD04, A01–A03, payments, mentors, sessions, settings), dev
  shared/widgets Figma components: Button, Chip, Badge, Avatar, Form/*, Navigation/*,
                 Card/Mentor Match, Brand/Logo Mark, Brand/Wordmark
supabase/
  migrations/    schema, business rules, RLS, storage
  seed.sql       fake UB data (5 mentors, 4 applicants, 15 learners, 1 admin)
  functions/
    match-mentors/     rule-based top 3 + Gemini one-line reasons
    tag-preferences/   saves the quiz, Gemini tags from a fixed vocabulary
    create-payment/    paid booking (inserted as the user) + Midtrans SANDBOX Snap
    payment-status/    "Check payment status": asks Midtrans, updates our rows
    midtrans-webhook/  sandbox notification: signature check, then GET status
    _shared/           gaps.ts, ranking.ts, tags.ts (pure, Deno-tested), gemini.ts, http.ts
  templates/     otp_code.html (6-digit sign-in code email)
tool/            gen_demo_seed.dart
```

- **State:** Riverpod 3. **Routing:** go_router with one `StatefulShellRoute` per role. Each role can only open its own area (`/learner`, `/mentor`, `/admin`).
- **Responsive:** one widget per screen. Below 600 px: phone layout with bottom nav. From 600 to 899 px: the same layout, centered. From 900 px: sidebar and two panes.
- **Fonts:** Inter is bundled (`assets/fonts/inter`, SIL OFL), so the app works offline.
- **Time:** all campus times are WIB (UTC+7). Instants are stored as `timestamptz` and shown in WIB whatever the device zone.

### Matching (`match-mentors`)

1. Verified mentors for the course (`mentor_courses`), optionally under a price cap.
2. Keep mentors who share at least one free gap of 30+ minutes with the learner: Monday to Friday, 07:00 to 17:00 WIB, next 7 days, starting at least an hour from now. Both timetables and both people's open bookings count as busy.
3. Rank by preference fit (learner tags found in the mentor's teaching tags or bio), then earliest shared slot, then price.
4. Top 3. One Gemini call per result writes a one-line reason. The prompt gets tags, the mentor's public bio and the slot only, never the learner's name or free-text answer. If Gemini fails or returns something unusable, a fixed template sentence is used and the app says so.

### Admin review

- Applications are listed oldest first. A GPA claim under `app_config.min_gpa` is marked **Needs check**.
- The KHS opens through a **signed link that expires after 5 minutes**. The bucket stays private.
- The system checks the price range and the signed agreement. The admin must confirm three things **by eye** before **Approve** turns on: the name, the grade or GPA, and that the document is clear. There is no OCR, and the screen says so.
- **Reject** needs a reason (chips or free text), which the applicant sees on M03.
- `review_application()` approves (and creates the `mentor_courses` row) or rejects, and is admin-only in the database.

### Payments (`create-payment`, `payment-status`, `midtrans-webhook`)

1. L12 "Pay": the booking is inserted **with the learner's own token**, so RLS and the booking rules still apply. The price comes from `mentor_courses`, never from the app, and the fee split from `payment_split()`.
2. A Midtrans **sandbox** Snap transaction is created (QRIS: `other_qris`; VA: BCA, BNI, BRI, Mandiri bill) with a 15-minute expiry and no customer name or email.
3. L13 opens the Snap page in a WebView on Android, or a browser tab on web. "Check payment status" and the webhook both call `GET /v2/{order_id}/status` and apply the result idempotently: paid → `held`, expired or failed → booking `cancelled`. The amount must match what we charged.
4. L15: once the session has started, each side taps "Confirm attendance". When both have confirmed, the `attendance_release` trigger releases the payment and writes a **simulated** payout.

`tag-preferences` sends the learner's open answer to Gemini and keeps only tags from a fixed vocabulary, so the AI cannot invent ranking inputs. A keyword fallback (English and Indonesian) covers Gemini failures. The quiz screen asks learners not to include personal details.

### Rules enforced in the database

| Rule | Where |
| --- | --- |
| Sign-up only with `@student.ub.ac.id` or `@ub.ac.id` | `handle_new_user` trigger on `auth.users`, domains in `app_config` |
| Users cannot make themselves admin | `profiles_guard` trigger |
| One 30-minute free trial per learner–mentor pair | partial unique index plus `bookings_insert_guard` |
| Mentor price inside the course's suggested range (default Rp15.000–Rp40.000) | `check_price_in_range` trigger, range in `app_config` / `courses` |
| Platform fee is a config value (10%, matching the designs) | `app_config.platform_fee_percent`, `payment_split()` |
| Payment released only after both learner and mentor confirm | `attendance_release` trigger creates a **simulated** payout |
| KHS files readable only by the owner and admins | private `khs` bucket, storage policies |
| Only admins review applications | `review_application()` |
| Mentors only see and accept paid requests once the payment is held | `respond_to_booking()` (and the M04 filter) |
| Mentors read a learner's quiz answers only when that learner booked them for the course | `preferences mentor read` policy |

RLS is enabled on every table. Other users' names are exposed only through the `profile_cards` view (no email, no NIM).

## Real vs simulated

| Area | Status |
| --- | --- |
| Supabase Auth, Postgres, Storage, RLS | Real |
| UB email restriction | Real (database trigger) |
| Gemini tags and match reasons | Real API call (free tier), with keyword / template fallbacks; labelled "written by AI" in the app |
| Matching and free-gap calculation | Real, rule-based (Edge Function) |
| Free-trial booking requests | Real (database enforces one trial per pair) |
| Debug "Dev preview" | **Offline fake data**, debug builds only, labelled on every screen |
| Midtrans QRIS and virtual account | **Sandbox only.** `payments.is_sandbox` is forced to true, non-sandbox keys are refused, and the UI shows "Midtrans sandbox · test payment" on every payment screen |
| Mentor payouts and "Withdraw (simulated)" | **Simulated.** Database records only; M04 and M05 say so on screen |
| Seed users, NIMs, timetables, bookings, KHS files | **Fake test data** (`@seed.skillshift.test`, `is_test_data = true`) |
| Ratings, chat | Not built (out of scope) |

## Tests

```bash
flutter analyze
flutter test
cd supabase/functions && deno test _shared/
```

- **Flutter:** role-guard redirect, formatters, free-gap and WIB time helpers, booking slot starts, widget smoke tests for the phone and wide shells, and end-to-end learner flows in preview mode: quiz → matches → profile → free-trial request; paid booking → checkout → (simulated) payment → booked → session; confirm attendance; mentor home (unpaid requests hidden, accept), mentor attendance, simulated earnings, and apply for a course (M01 → M02 → M03); admin dashboard, application tabs and search, approve only after the three manual checks, reject only with a reason, and the wide A01/A03 layouts.
- **Deno:** Midtrans status mapping, safe state transitions (duplicate or late notifications), order ids, amounts, webhook signature; free-gap calculation and shared slots (time zones, today's lead time, bookings as busy, 30-minute minimum), ranking order, fallback reasons, tag sanitising and the keyword fallback.

## Design

Figma: *SkillShift UI*, with pages `00 Design System`, `01 Phone`, `02 Tablet & Admin`. The color and type tokens live in `lib/core/theme/`.

`assets/brand/logo_mark.svg` is currently a **hand-drawn placeholder**. Replace it with the SVG exported from the Figma `Brand/Logo Mark` component (same file name).

## Material AI assistance

This project was built with help from **Claude Code** (Anthropic's AI coding assistant), as required by the competition rules. The team set the product, the designs (Figma), the data model and the rules. Claude Code was used to:

- read the Figma frames and turn the design tokens into Flutter theme code and shared widgets,
- write the routing, role guards and adaptive layout,
- write the learner screens and the matching / tagging Edge Functions (the team defined the matching rules),
- write the Supabase migrations, RLS policies, seed data and helper scripts,
- write tests and this README.

The team reviews all generated code before each commit.
