-- Business rules enforced in the database (not only in the UI).
-- Functions that bypass RLS are SECURITY DEFINER with an empty search_path
-- and check the caller themselves.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

-- Suggested price range for a course (course override, else default).
create or replace function public.price_range(p_course_id uuid)
returns table (price_min integer, price_max integer)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(c.price_min, cfg.default_price_min),
         coalesce(c.price_max, cfg.default_price_max)
  from public.app_config cfg
  left join public.courses c on c.id = p_course_id
  where cfg.id;
$$;

-- Platform fee split for a gross amount, using the configured percentage.
create or replace function public.payment_split(p_gross integer)
returns table (platform_fee integer, mentor_net integer)
language sql
stable
security definer
set search_path = ''
as $$
  select f.fee, p_gross - f.fee
  from (
    select round(p_gross * cfg.platform_fee_percent / 100)::integer as fee
    from public.app_config cfg where cfg.id
  ) f;
$$;

-- ---------------------------------------------------------------------------
-- New users: UB email only, then create the profile row.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_domain text := lower(split_part(new.email, '@', 2));
  v_is_test boolean :=
    coalesce((new.raw_app_meta_data ->> 'is_test_data')::boolean, false);
  v_allowed text[];
begin
  select allowed_email_domains into v_allowed
  from public.app_config where id;

  -- Seeded test users use the reserved .test domain and must carry the
  -- is_test_data flag in app metadata (clients cannot set app metadata).
  if not (v_domain = any (v_allowed)
          or (v_is_test and v_domain = 'seed.skillshift.test')) then
    raise exception 'Only UB email addresses can join SkillShift'
      using errcode = 'P0001';
  end if;

  insert into public.profiles (id, email, full_name, is_test_data)
  values (
    new.id,
    lower(new.email),
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    v_is_test
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Profiles: users cannot make themselves admin or change locked fields.
-- ---------------------------------------------------------------------------
create or replace function public.profiles_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Service role, migrations and seeds have no auth.uid().
  if (select auth.uid()) is null or public.is_admin() then
    return new;
  end if;

  if new.id <> old.id or new.email <> old.email
     or new.is_test_data <> old.is_test_data then
    raise exception 'These profile fields cannot be changed';
  end if;

  if new.role is distinct from old.role
     and (new.role = 'admin' or old.role = 'admin') then
    raise exception 'The admin role is assigned by SkillShift staff';
  end if;
  return new;
end;
$$;

create trigger profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();

-- ---------------------------------------------------------------------------
-- Prices must be inside the suggested range for the course.
-- ---------------------------------------------------------------------------
create or replace function public.check_price_in_range()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
begin
  select * into r from public.price_range(new.course_id);
  if new.price_per_hour < r.price_min or new.price_per_hour > r.price_max then
    raise exception 'Price must be between Rp% and Rp% per hour',
      r.price_min, r.price_max
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger mentor_applications_price before insert or update of price_per_hour, course_id
  on public.mentor_applications
  for each row execute function public.check_price_in_range();

create trigger mentor_courses_price before insert or update of price_per_hour, course_id
  on public.mentor_courses
  for each row execute function public.check_price_in_range();

-- ---------------------------------------------------------------------------
-- Mentor applications: a user can only file a pending application for self.
-- ---------------------------------------------------------------------------
create or replace function public.mentor_applications_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;

  new.mentor_id := (select auth.uid());
  new.status := 'pending';
  new.reject_reason := null;
  new.reviewed_by := null;
  new.reviewed_at := null;

  if new.khs_path is null
     or split_part(new.khs_path, '/', 1) <> (select auth.uid())::text then
    raise exception 'KHS file must be uploaded to your own folder';
  end if;

  -- A GPA below app_config.min_gpa is still accepted for review (the admin
  -- sees "Needs check"), but a GPA claim needs a GPA value.
  if new.proof_type = 'gpa' and new.gpa is null then
    raise exception 'GPA is required for a GPA-based application';
  end if;
  return new;
end;
$$;

create trigger mentor_applications_guard before insert
  on public.mentor_applications
  for each row execute function public.mentor_applications_guard();

-- Admin approves or rejects. Approval creates/updates the mentor_course.
create or replace function public.review_application(
  p_application_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns public.mentor_applications
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.mentor_applications;
begin
  if not public.is_admin() then
    raise exception 'Only admins can review applications'
      using errcode = '42501';
  end if;

  select * into a from public.mentor_applications
  where id = p_application_id for update;
  if not found then
    raise exception 'Application not found';
  end if;
  if a.status <> 'pending' then
    raise exception 'Application was already reviewed';
  end if;

  if p_approve then
    update public.mentor_applications
      set status = 'approved',
          reviewed_by = (select auth.uid()),
          reviewed_at = now()
      where id = a.id
      returning * into a;

    insert into public.mentor_courses
      (mentor_id, course_id, price_per_hour, verified_at, application_id)
    values (a.mentor_id, a.course_id, a.price_per_hour, now(), a.id)
    on conflict (mentor_id, course_id) do update
      set price_per_hour = excluded.price_per_hour,
          verified_at = excluded.verified_at,
          application_id = excluded.application_id;
  else
    if coalesce(trim(p_reason), '') = '' then
      raise exception 'A reason is required to reject an application';
    end if;
    update public.mentor_applications
      set status = 'rejected',
          reject_reason = trim(p_reason),
          reviewed_by = (select auth.uid()),
          reviewed_at = now()
      where id = a.id
      returning * into a;
  end if;
  return a;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------
create or replace function public.bookings_insert_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trial_minutes smallint;
begin
  -- Seeds and the service role skip the caller checks (not the table checks).
  if (select auth.uid()) is null then
    return new;
  end if;

  if new.learner_id <> (select auth.uid()) then
    raise exception 'You can only book sessions for yourself';
  end if;
  new.status := 'requested';

  if new.starts_at <= now() then
    raise exception 'Sessions must start in the future';
  end if;

  if not exists (
    select 1 from public.mentor_courses mc
    where mc.mentor_id = new.mentor_id and mc.course_id = new.course_id
  ) then
    raise exception 'This mentor is not verified for this course';
  end if;

  if new.is_free_trial then
    select free_trial_minutes into v_trial_minutes
    from public.app_config where id;
    if new.duration_min <> v_trial_minutes then
      raise exception 'Free trial sessions are % minutes', v_trial_minutes;
    end if;
    if exists (
      select 1 from public.bookings b
      where b.learner_id = new.learner_id
        and b.mentor_id = new.mentor_id
        and b.is_free_trial
        and b.status not in ('declined', 'cancelled')
    ) then
      raise exception 'You already used your free trial with this mentor'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

create trigger bookings_insert_guard before insert on public.bookings
  for each row execute function public.bookings_insert_guard();

-- Mentor accepts or declines a requested booking.
create or replace function public.respond_to_booking(
  p_booking_id uuid,
  p_accept boolean
)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if not found or b.mentor_id <> (select auth.uid()) then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status <> 'requested' then
    raise exception 'This request was already answered';
  end if;

  update public.bookings
    set status = case when p_accept then 'accepted'::public.booking_status
                      else 'declined'::public.booking_status end
    where id = b.id
    returning * into b;

  -- A declined paid request is refunded (sandbox: status change only).
  if not p_accept then
    update public.payments set status = 'refunded'
    where booking_id = b.id and status in ('paid', 'held');
  end if;
  return b;
end;
$$;

-- Learner or mentor cancels before the session starts.
create or replace function public.cancel_booking(p_booking_id uuid)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings;
  v_uid uuid := (select auth.uid());
begin
  select * into b from public.bookings where id = p_booking_id for update;
  if not found or v_uid not in (b.learner_id, b.mentor_id) then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status not in ('requested', 'accepted') then
    raise exception 'This session can no longer be cancelled';
  end if;
  if b.starts_at <= now() then
    raise exception 'The session has already started';
  end if;

  update public.bookings set status = 'cancelled'
  where id = b.id returning * into b;

  update public.payments set status = 'refunded'
  where booking_id = b.id and status in ('paid', 'held');
  return b;
end;
$$;

-- ---------------------------------------------------------------------------
-- Attendance: payment is released only after BOTH sides confirm.
-- ---------------------------------------------------------------------------
create or replace function public.confirm_attendance(p_booking_id uuid)
returns public.attendance
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings;
  v_uid uuid := (select auth.uid());
  a public.attendance;
begin
  select * into b from public.bookings where id = p_booking_id;
  if not found or v_uid not in (b.learner_id, b.mentor_id) then
    raise exception 'Booking not found' using errcode = '42501';
  end if;
  if b.status not in ('accepted', 'completed') then
    raise exception 'Only accepted sessions can be confirmed';
  end if;
  if now() < b.starts_at then
    raise exception 'You can confirm attendance once the session has started';
  end if;

  insert into public.attendance (booking_id, user_id)
  values (b.id, v_uid)
  on conflict (booking_id, user_id) do nothing;

  select * into a from public.attendance
  where booking_id = b.id and user_id = v_uid;
  return a;
end;
$$;

create or replace function public.release_when_both_confirmed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.bookings;
  p public.payments;
begin
  select * into b from public.bookings where id = new.booking_id for update;

  if (select count(*) from public.attendance at
      where at.booking_id = b.id
        and at.user_id in (b.learner_id, b.mentor_id)) < 2 then
    return new;
  end if;

  update public.bookings set status = 'completed'
  where id = b.id and status = 'accepted';

  update public.payments
    set status = 'released', released_at = now()
    where booking_id = b.id and status = 'held'
    returning * into p;

  if found then
    insert into public.payouts (mentor_id, payment_id, amount)
    values (b.mentor_id, p.id, p.mentor_net)
    on conflict (payment_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger attendance_release after insert on public.attendance
  for each row execute function public.release_when_both_confirmed();

-- These run with elevated rights; expose only what clients need.
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.release_when_both_confirmed() from public, anon, authenticated;
revoke execute on function public.review_application(uuid, boolean, text) from public, anon;
revoke execute on function public.respond_to_booking(uuid, boolean) from public, anon;
revoke execute on function public.cancel_booking(uuid) from public, anon;
revoke execute on function public.confirm_attendance(uuid) from public, anon;
grant execute on function public.review_application(uuid, boolean, text) to authenticated;
grant execute on function public.respond_to_booking(uuid, boolean) to authenticated;
grant execute on function public.cancel_booking(uuid) to authenticated;
grant execute on function public.confirm_attendance(uuid) to authenticated;
grant execute on function public.price_range(uuid) to authenticated;
grant execute on function public.payment_split(integer) to authenticated;
