-- Phase 4: mentor flows.

-- A mentor may read the quiz answers ("Anything your mentor should know?")
-- of learners who booked them for that course, to prepare the session.
create policy "preferences mentor read" on public.learner_preferences
  for select to authenticated
  using (
    exists (
      select 1 from public.bookings b
      where b.mentor_id = (select auth.uid())
        and b.learner_id = learner_preferences.user_id
        and b.course_id = learner_preferences.course_id
    )
  );

-- Mentors only accept paid requests once the payment is held.
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
  if p_accept and not b.is_free_trial and not exists (
    select 1 from public.payments p
    where p.booking_id = b.id and p.status = 'held'
  ) then
    raise exception 'The learner has not paid yet';
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

revoke execute on function public.respond_to_booking(uuid, boolean) from public, anon;
grant execute on function public.respond_to_booking(uuid, boolean) to authenticated;
