# SkillShift

Peer tutoring for Universitas Brawijaya (UB) students. First-year learners get matched with verified seniors who are free in the same class gaps, and meet on campus. The first 30-minute session with each mentor is free. Later sessions are paid with QRIS or a virtual account, held by the platform and released to the mentor only after both sides confirm attendance.

> **Prototype for STACK 2026.** Payments use the **Midtrans sandbox** (test transactions only). **Mentor payouts are simulated** (database records, no money moves). Seed data is **fake test data**. The app labels all three in the UI.

## Status

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Theme and tokens, shared widgets, routing and role guards, adaptive shell, Supabase schema, RLS, seed | **Done** |
| 2 | Learner core: L01–L11, matching Edge Function, Gemini tags and reasons | Planned |
| 3 | Checkout, QRIS (Midtrans sandbox), booking confirmed, attendance: L12–L15 | Planned |
| 4 | Mentor: M01–M05 | Planned |
| 5 | Admin: AD01–AD04, A01–A03 | Planned |
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

Without a `.env` the app still runs: it shows the splash, then a welcome screen saying Supabase is not configured. In **debug builds** that screen also offers:

- **Preview as learner / mentor / admin**: opens the role's navigation shell offline, marked with a "Dev preview" strip.
- **Component gallery**: every shared widget next to the Figma design system.

### Local Supabase

Needs Docker Desktop (which needs WSL 2 on Windows).

```bash
supabase start                      # prints the local URL and anon key
dart run tool/gen_demo_seed.dart    # optional: demo password for seed accounts
supabase db reset                   # applies migrations + seed.sql (+ seed.local.sql)
```

From the Android emulator the local API is at `http://10.0.2.2:54321`.

### Remote Supabase

Do not run these against the shared project without agreeing first.

```bash
supabase link --project-ref <ref>
supabase db push
supabase secrets set --env-file supabase/functions/.env
```

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
| `GEMINI_MODEL` | Model name, configurable (default `gemini-2.5-flash`) |
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
    utils/       Rupiah formatting, NIM masking, UB email check, fee split
  features/      one folder per feature (onboarding, dev, later learner/mentor/admin)
  shared/widgets Figma components: Button, Chip, Badge, Avatar, Form/*, Navigation/*,
                 Card/Mentor Match, Brand/Logo Mark, Brand/Wordmark
supabase/
  migrations/    schema, business rules, RLS, storage
  seed.sql       fake UB data (5 mentors, 4 applicants, 15 learners, 1 admin)
tool/            gen_demo_seed.dart
```

- **State:** Riverpod 3. **Routing:** go_router with one `StatefulShellRoute` per role. Each role can only open its own area (`/learner`, `/mentor`, `/admin`).
- **Responsive:** one widget per screen. Below 600 px: phone layout with bottom nav. From 600 to 899 px: the same layout, centered. From 900 px: sidebar and two panes.
- **Fonts:** Inter is bundled (`assets/fonts/inter`, SIL OFL), so the app works offline.

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

RLS is enabled on every table. Other users' names are exposed only through the `profile_cards` view (no email, no NIM).

## Real vs simulated

| Area | Status |
| --- | --- |
| Supabase Auth, Postgres, Storage, RLS | Real |
| UB email restriction | Real (database trigger) |
| Gemini tags and match reasons (Phase 2) | Real API call, with a fixed fallback sentence if it fails |
| Midtrans QRIS and virtual account (Phase 3) | **Sandbox only.** `payments.is_sandbox` is forced to true |
| Mentor payouts and "Withdraw" (Phase 4) | **Simulated.** Database records only |
| Seed users, NIMs, timetables, bookings, KHS files | **Fake test data** (`@seed.skillshift.test`, `is_test_data = true`) |
| Ratings, chat | Not built (out of scope) |

## Tests

```bash
flutter analyze
flutter test
```

Covered so far: the role-guard redirect, formatters (Rupiah, NIM masking, UB email check, fee split), and widget smoke tests for the phone and wide shells.

## Design

Figma: *SkillShift UI*, with pages `00 Design System`, `01 Phone`, `02 Tablet & Admin`. The color and type tokens live in `lib/core/theme/`.

`assets/brand/logo_mark.svg` is currently a **hand-drawn placeholder**. Replace it with the SVG exported from the Figma `Brand/Logo Mark` component (same file name).

## Material AI assistance

This project was built with help from **Claude Code** (Anthropic's AI coding assistant), as required by the competition rules. The team set the product, the designs (Figma), the data model and the rules. Claude Code was used to:

- read the Figma frames and turn the design tokens into Flutter theme code and shared widgets,
- write the routing, role guards and adaptive layout,
- write the Supabase migrations, RLS policies, seed data and helper scripts,
- write tests and this README.

The team reviews all generated code before each commit.
