// match-mentors: top 3 verified mentors for a course, rule-based.
//   1. mentors with a verified mentor_course for the course
//   2. who share at least one free gap of 30+ min with the learner
//      (Mon–Fri, 07:00–17:00 WIB, next 7 days; existing bookings count as busy)
//   3. ranked by preference fit, then earliest shared slot, then price
//   4. one Gemini sentence per result, with a deterministic fallback.
//
// POST { course_id: uuid, max_price?: number }

import {
  type BusyInstant,
  dayTime,
  type Entry,
  sharedSlots,
} from "../_shared/gaps.ts";
import { generate } from "../_shared/gemini.ts";
import {
  handler,
  HttpError,
  isUuid,
  json,
  requireUser,
  serviceClient,
} from "../_shared/http.ts";
import {
  cleanReason,
  fallbackReason,
  preferenceFit,
  rankCandidates,
} from "../_shared/ranking.ts";
import { isLearningStyle, withStyle } from "../_shared/tags.ts";

const ACTIVE = ["requested", "accepted"];

Deno.serve(handler(async (req, body) => {
  const db = serviceClient();
  const learnerId = await requireUser(req, db);

  const courseId = body.course_id;
  if (!isUuid(courseId)) throw new HttpError(400, "Pick a course first.");
  const maxPrice = typeof body.max_price === "number" ? body.max_price : null;
  const now = new Date();
  const horizon = new Date(now.getTime() + 8 * 24 * 3600 * 1000);

  const [courseRes, learnerTtRes, prefRes, mcRes] = await Promise.all([
    db.from("courses").select("id, code, name").eq("id", courseId)
      .maybeSingle(),
    db.from("timetable_entries")
      .select("day_of_week, start_time, end_time")
      .eq("user_id", learnerId),
    db.from("learner_preferences")
      .select("learning_style, ai_tags")
      .eq("user_id", learnerId)
      .eq("course_id", courseId)
      .maybeSingle(),
    db.from("mentor_courses")
      .select("mentor_id, price_per_hour")
      .eq("course_id", courseId)
      .neq("mentor_id", learnerId),
  ]);
  for (const r of [courseRes, learnerTtRes, prefRes, mcRes]) {
    if (r.error) throw r.error;
  }
  const course = courseRes.data;
  if (!course) throw new HttpError(404, "Course not found.");

  const style = prefRes.data?.learning_style;
  const learnerTags: string[] = isLearningStyle(style)
    ? withStyle(style, prefRes.data?.ai_tags ?? [])
    : (prefRes.data?.ai_tags ?? []);

  let offers = mcRes.data ?? [];
  if (maxPrice !== null) {
    offers = offers.filter((o) => o.price_per_hour <= maxPrice);
  }
  if (offers.length === 0) return json({ course, matches: [] });
  const mentorIds = offers.map((o) => o.mentor_id);

  const [profilesRes, mentorTtRes, appsRes, taughtRes, busyRes, trialsRes] =
    await Promise.all([
      db.from("profiles")
        .select("id, full_name, program, cohort_year, bio, teaching_tags")
        .in("id", mentorIds),
      db.from("timetable_entries")
        .select("user_id, day_of_week, start_time, end_time")
        .in("user_id", mentorIds),
      db.from("mentor_applications")
        .select("mentor_id, proof_type, gpa, reviewed_at")
        .eq("course_id", courseId)
        .eq("status", "approved")
        .in("mentor_id", mentorIds)
        .order("reviewed_at", { ascending: false }),
      db.from("mentor_courses")
        .select("mentor_id, course:courses(name)")
        .in("mentor_id", mentorIds),
      db.from("bookings")
        .select("learner_id, mentor_id, starts_at, duration_min")
        .in("status", ACTIVE)
        .gte(
          "starts_at",
          new Date(now.getTime() - 2 * 3600 * 1000).toISOString(),
        )
        .lte("starts_at", horizon.toISOString())
        .or(
          `learner_id.eq.${learnerId},mentor_id.eq.${learnerId},` +
            `mentor_id.in.(${mentorIds.join(",")}),learner_id.in.(${
              mentorIds.join(",")
            })`,
        ),
      db.from("bookings")
        .select("mentor_id, starts_at")
        .eq("learner_id", learnerId)
        .eq("is_free_trial", true)
        .not("status", "in", "(declined,cancelled)")
        .in("mentor_id", mentorIds),
    ]);
  for (
    const r of [
      profilesRes,
      mentorTtRes,
      appsRes,
      taughtRes,
      busyRes,
      trialsRes,
    ]
  ) {
    if (r.error) throw r.error;
  }

  const learnerTt = (learnerTtRes.data ?? []) as Entry[];
  const toBusy = (
    b: { starts_at: string; duration_min: number },
  ): BusyInstant => {
    const startsAt = new Date(b.starts_at);
    return {
      startsAt,
      endsAt: new Date(startsAt.getTime() + b.duration_min * 60000),
    };
  };
  const learnerBusy = (busyRes.data ?? [])
    .filter((b) => b.learner_id === learnerId || b.mentor_id === learnerId)
    .map(toBusy);

  const candidates = [];
  for (const offer of offers) {
    const id = offer.mentor_id;
    const profile = profilesRes.data?.find((p) => p.id === id);
    if (!profile) continue;
    const mentorBusy = (busyRes.data ?? [])
      .filter((b) => b.mentor_id === id || b.learner_id === id)
      .map(toBusy);
    const slots = sharedSlots({
      now,
      learner: learnerTt,
      mentor: (mentorTtRes.data ?? []).filter((e) =>
        e.user_id === id
      ) as Entry[],
      busy: [...learnerBusy, ...mentorBusy],
    });
    if (slots.length === 0) continue; // must share at least one 30+ min gap

    const teachingTags: string[] = profile.teaching_tags ?? [];
    const app = appsRes.data?.find((a) => a.mentor_id === id);
    const trial = trialsRes.data?.find((t) => t.mentor_id === id);
    candidates.push({
      mentorId: id,
      fit: preferenceFit(learnerTags, teachingTags, profile.bio),
      earliest: slots[0].start,
      price: offer.price_per_hour,
      profile,
      teachingTags,
      slots,
      proofType: app?.proof_type ?? "grade_a",
      gpa: app?.gpa ?? null,
      courses: (taughtRes.data ?? [])
        .filter((t) => t.mentor_id === id)
        // deno-lint-ignore no-explicit-any
        .map((t) => (t.course as any)?.name)
        .filter(Boolean),
      trialUsedOn: trial?.starts_at ?? null,
    });
  }

  const top = rankCandidates(candidates).slice(0, 3);

  const matches = await Promise.all(top.map(async (c) => {
    const first = c.slots[0];
    const fallback = fallbackReason({
      slotStart: first.start,
      learnerTags,
      mentorTags: c.teachingTags,
    });
    // Data minimisation: no learner name, email or free-text answer here.
    const prompt =
      `You write one short sentence (max 20 words, English) telling a ` +
      `first-year university student why a senior tutor is a good match for ` +
      `"${course.name}". Mention the shared free time "${
        dayTime(first.start)
      }" ` +
      `and at most one teaching-style or topic overlap. No names, no emojis, ` +
      `no quotes, no promises about grades.\n` +
      `Student preference tags: ${learnerTags.join(", ") || "none"}.\n` +
      `Tutor teaching tags: ${c.teachingTags.join(", ") || "none"}.\n` +
      `Tutor bio: ${(c.profile.bio ?? "").slice(0, 300)}`;
    const ai = cleanReason(await generate(prompt, { maxTokens: 60 }));

    return {
      mentor_id: c.mentorId,
      full_name: c.profile.full_name,
      program: c.profile.program,
      cohort_year: c.profile.cohort_year,
      bio: c.profile.bio,
      teaching_tags: c.teachingTags,
      courses: c.courses,
      proof_type: c.proofType,
      gpa: c.gpa,
      price_per_hour: c.price,
      fit: c.fit,
      reason: ai ?? fallback,
      reason_source: ai ? "ai" : "fallback",
      slot: {
        starts_at: first.start.toISOString(),
        ends_at: new Date(
          Math.min(first.end.getTime(), first.start.getTime() + 60 * 60000),
        ).toISOString(),
      },
      shared_slots: c.slots.map((s) => ({
        starts_at: s.start.toISOString(),
        ends_at: s.end.toISOString(),
      })),
      free_trial_available: c.trialUsedOn === null,
      free_trial_used_on: c.trialUsedOn,
    };
  }));

  return json({ course, matches });
}));
