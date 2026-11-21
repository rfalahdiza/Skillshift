-- Row Level Security on every table. Default deny; each policy opens the
-- minimum. State changes on bookings, applications and payments go through
-- the SECURITY DEFINER functions in 20261121000200_rules.sql or through
-- Edge Functions using the service role.

alter table public.app_config enable row level security;
alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.timetable_entries enable row level security;
alter table public.learner_preferences enable row level security;
alter table public.mentor_applications enable row level security;
alter table public.mentor_courses enable row level security;
alter table public.bookings enable row level security;
alter table public.payments enable row level security;
alter table public.attendance enable row level security;
alter table public.payouts enable row level security;

-- Nothing is readable without signing in.
revoke all on all tables in schema public from anon;

-- ---------------------------------------------------------------------------
-- app_config: everyone signed in reads, admins edit.
-- ---------------------------------------------------------------------------
grant select, update on public.app_config to authenticated;

create policy "config readable" on public.app_config
  for select to authenticated using (true);
create policy "config admin update" on public.app_config
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- profiles: own row (and admins). Others see the limited profile_cards view.
-- ---------------------------------------------------------------------------
grant select, update on public.profiles to authenticated;

create policy "profiles own or admin read" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());
create policy "profiles own update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
create policy "profiles admin update" on public.profiles
  for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Public card for a person: no email, no NIM. Visible only for verified
-- mentors, people you share a booking with, yourself, or to admins.
create view public.profile_cards
with (security_barrier = true)
as
select p.id, p.full_name, p.program, p.cohort_year, p.role, p.bio,
       p.teaching_tags, p.is_test_data
from public.profiles p
where p.id = (select auth.uid())
   or public.is_admin()
   or exists (select 1 from public.mentor_courses mc where mc.mentor_id = p.id)
   or exists (
     select 1 from public.bookings b
     where (b.learner_id = (select auth.uid()) and b.mentor_id = p.id)
        or (b.mentor_id = (select auth.uid()) and b.learner_id = p.id)
   );
comment on view public.profile_cards is
  'Owner-rights view (bypasses profiles RLS by design) exposing only '
  'non-sensitive fields, filtered by the WHERE clause above.';
revoke all on public.profile_cards from anon;
grant select on public.profile_cards to authenticated;

-- ---------------------------------------------------------------------------
-- courses: readable; admins manage.
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on public.courses to authenticated;

create policy "courses readable" on public.courses
  for select to authenticated using (true);
create policy "courses admin write" on public.courses
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- timetable_entries / learner_preferences: owner only (admins read).
-- Matching reads other users' timetables in an Edge Function.
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on public.timetable_entries to authenticated;

create policy "timetable own" on public.timetable_entries
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "timetable admin read" on public.timetable_entries
  for select to authenticated using (public.is_admin());

grant select, insert, update, delete on public.learner_preferences to authenticated;

create policy "preferences own" on public.learner_preferences
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- mentor_applications: applicant inserts and reads own; admin reads all.
-- Review happens only through review_application().
-- ---------------------------------------------------------------------------
grant select, insert on public.mentor_applications to authenticated;

create policy "applications own read" on public.mentor_applications
  for select to authenticated
  using (mentor_id = (select auth.uid()) or public.is_admin());
create policy "applications own insert" on public.mentor_applications
  for insert to authenticated
  with check (mentor_id = (select auth.uid()) and status = 'pending');

-- ---------------------------------------------------------------------------
-- mentor_courses: public list of verified mentors; written on approval.
-- ---------------------------------------------------------------------------
grant select on public.mentor_courses to authenticated;

create policy "mentor courses readable" on public.mentor_courses
  for select to authenticated using (true);

-- ---------------------------------------------------------------------------
-- bookings: participants read; learner creates (guard trigger checks rules).
-- Status changes via respond_to_booking / cancel_booking / attendance.
-- ---------------------------------------------------------------------------
grant select, insert on public.bookings to authenticated;

create policy "bookings participants read" on public.bookings
  for select to authenticated
  using ((select auth.uid()) in (learner_id, mentor_id) or public.is_admin());
create policy "bookings learner insert" on public.bookings
  for insert to authenticated
  with check (learner_id = (select auth.uid()) and status = 'requested');

-- ---------------------------------------------------------------------------
-- payments / attendance: participants read. Written by Edge Functions
-- (service role) and confirm_attendance().
-- ---------------------------------------------------------------------------
grant select on public.payments to authenticated;

create policy "payments participants read" on public.payments
  for select to authenticated
  using (
    public.is_admin() or exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (select auth.uid()) in (b.learner_id, b.mentor_id)
    )
  );

grant select on public.attendance to authenticated;

create policy "attendance participants read" on public.attendance
  for select to authenticated
  using (
    public.is_admin() or exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (select auth.uid()) in (b.learner_id, b.mentor_id)
    )
  );

-- ---------------------------------------------------------------------------
-- payouts (simulated): mentor reads own, admin reads all.
-- ---------------------------------------------------------------------------
grant select on public.payouts to authenticated;

create policy "payouts own read" on public.payouts
  for select to authenticated
  using (mentor_id = (select auth.uid()) or public.is_admin());
