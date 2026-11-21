-- SkillShift core schema.
-- Times are stored as timestamptz; the app shows them in Asia/Jakarta (WIB).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('learner', 'mentor', 'admin');
create type public.proof_type as enum ('grade_a', 'gpa');
create type public.application_status as enum ('pending', 'approved', 'rejected');
create type public.booking_status as enum
  ('requested', 'accepted', 'declined', 'completed', 'cancelled');
create type public.payment_method as enum ('qris', 'va');
create type public.payment_status as enum
  ('pending', 'paid', 'held', 'released', 'refunded');
create type public.learning_style as enum
  ('worked_examples', 'concept_first', 'practice_together');

-- ---------------------------------------------------------------------------
-- Generic updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Config (single row). Business rules read from here, never hard-coded.
-- ---------------------------------------------------------------------------
create table public.app_config (
  id boolean primary key default true check (id),
  platform_fee_percent numeric(5, 2) not null default 10
    check (platform_fee_percent >= 0 and platform_fee_percent <= 50),
  default_price_min integer not null default 15000,
  default_price_max integer not null default 40000,
  free_trial_minutes smallint not null default 30,
  min_gpa numeric(3, 2) not null default 3.50,
  allowed_email_domains text[] not null
    default array['student.ub.ac.id', 'ub.ac.id'],
  updated_at timestamptz not null default now(),
  check (default_price_min > 0 and default_price_max >= default_price_min)
);
comment on table public.app_config is
  'Single-row business config: platform fee, price range, allowed email domains.';

insert into public.app_config default values;

create trigger app_config_touch before update on public.app_config
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users, created by trigger)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text check (char_length(full_name) <= 120),
  -- Student number. Never shown in full; the app masks it (2451505••••••).
  nim text check (nim ~ '^[0-9]{8,20}$'),
  program text,
  cohort_year smallint check (cohort_year between 2000 and 2100),
  -- Null until the user picks a role on L05.
  role public.user_role,
  bio text check (char_length(bio) <= 600),
  -- Mentor teaching-style tags used for matching (e.g. worked_examples).
  teaching_tags text[] not null default '{}',
  is_test_data boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on column public.profiles.is_test_data is
  'True for seeded fake users (@seed.skillshift.test). Never real students.';

create index profiles_role_idx on public.profiles (role);

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Courses
-- ---------------------------------------------------------------------------
create table public.courses (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  -- Optional per-course override of the suggested price range.
  price_min integer check (price_min > 0),
  price_max integer,
  created_at timestamptz not null default now(),
  check (price_max is null or price_min is null or price_max >= price_min)
);

-- ---------------------------------------------------------------------------
-- Timetables
-- ---------------------------------------------------------------------------
create table public.timetable_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- ISO day: 1 = Monday ... 7 = Sunday. Matching uses Monday to Friday.
  day_of_week smallint not null check (day_of_week between 1 and 7),
  start_time time not null,
  end_time time not null,
  course_name text not null check (char_length(course_name) <= 120),
  room text check (char_length(room) <= 60),
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);
create index timetable_entries_user_idx
  on public.timetable_entries (user_id, day_of_week, start_time);

-- ---------------------------------------------------------------------------
-- Learner preferences (one row per learner per course)
-- ---------------------------------------------------------------------------
create table public.learner_preferences (
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  learning_style public.learning_style not null,
  open_answer text check (char_length(open_answer) <= 500),
  -- Filled by the tag-preferences Edge Function (Gemini).
  ai_tags text[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (user_id, course_id)
);

create trigger learner_preferences_touch before update
  on public.learner_preferences
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Mentor applications and verified mentor courses
-- ---------------------------------------------------------------------------
create table public.mentor_applications (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id),
  -- Path inside the private `khs` bucket: <mentor_id>/<file>.
  khs_path text not null,
  proof_type public.proof_type not null,
  gpa numeric(3, 2) check (gpa between 0 and 4),
  price_per_hour integer not null,
  agreed_no_graded_work boolean not null check (agreed_no_graded_work),
  status public.application_status not null default 'pending',
  reject_reason text check (char_length(reject_reason) <= 500),
  reviewed_by uuid references public.profiles (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (proof_type <> 'gpa' or gpa is not null),
  check (status <> 'rejected' or reject_reason is not null),
  check (status = 'pending' or reviewed_at is not null)
);
-- One open application per mentor per course.
create unique index mentor_applications_one_pending
  on public.mentor_applications (mentor_id, course_id)
  where status = 'pending';
create index mentor_applications_status_idx
  on public.mentor_applications (status, created_at);

create table public.mentor_courses (
  mentor_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id),
  price_per_hour integer not null,
  verified_at timestamptz not null default now(),
  application_id uuid references public.mentor_applications (id),
  primary key (mentor_id, course_id)
);
create index mentor_courses_course_idx on public.mentor_courses (course_id);

-- ---------------------------------------------------------------------------
-- Bookings, payments, attendance, payouts
-- ---------------------------------------------------------------------------
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  learner_id uuid not null references public.profiles (id),
  mentor_id uuid not null references public.profiles (id),
  course_id uuid not null references public.courses (id),
  starts_at timestamptz not null,
  duration_min smallint not null check (duration_min in (30, 60)),
  place text not null check (char_length(place) <= 120),
  is_free_trial boolean not null default false,
  status public.booking_status not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (learner_id <> mentor_id),
  -- Free trials are always 30 minutes.
  check (not is_free_trial or duration_min = 30)
);
-- One free trial per learner-mentor pair (a declined or cancelled one
-- does not count).
create unique index bookings_one_free_trial
  on public.bookings (learner_id, mentor_id)
  where is_free_trial and status not in ('declined', 'cancelled');
create index bookings_learner_idx on public.bookings (learner_id, starts_at);
create index bookings_mentor_idx on public.bookings (mentor_id, starts_at);

create trigger bookings_touch before update on public.bookings
  for each row execute function public.touch_updated_at();

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id),
  gross integer not null check (gross > 0),
  platform_fee integer not null check (platform_fee >= 0),
  mentor_net integer not null check (mentor_net >= 0),
  midtrans_order_id text unique,
  snap_redirect_url text,
  method public.payment_method,
  status public.payment_status not null default 'pending',
  -- This prototype only ever talks to the Midtrans sandbox.
  is_sandbox boolean not null default true check (is_sandbox),
  paid_at timestamptz,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (gross = platform_fee + mentor_net)
);
create index payments_status_idx on public.payments (status);

create trigger payments_touch before update on public.payments
  for each row execute function public.touch_updated_at();

create table public.attendance (
  booking_id uuid not null references public.bookings (id) on delete cascade,
  user_id uuid not null references public.profiles (id),
  confirmed_at timestamptz not null default now(),
  primary key (booking_id, user_id)
);

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references public.profiles (id),
  payment_id uuid not null unique references public.payments (id),
  amount integer not null check (amount >= 0),
  -- Payouts are database records only. No money moves.
  status text not null default 'simulated' check (status = 'simulated'),
  created_at timestamptz not null default now()
);
create index payouts_mentor_idx on public.payouts (mentor_id, created_at);
