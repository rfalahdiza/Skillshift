// Free-gap calculation for matching. Pure functions, unit-tested in
// gaps_test.ts. All campus times are WIB (UTC+7, no daylight saving).

export type Range = { start: number; end: number }; // minutes since midnight

export const DAY_START = 7 * 60; // 07:00
export const DAY_END = 17 * 60; // 17:00
export const MIN_GAP = 30;
const WIB_MS = 7 * 60 * 60 * 1000;
const MIN_MS = 60 * 1000;

/** Timetable row as stored in public.timetable_entries. */
export type Entry = {
  day_of_week: number; // ISO, 1 = Monday
  start_time: string; // "07:00" or "07:00:00"
  end_time: string;
};

/** An existing booking that makes someone busy. */
export type BusyInstant = { startsAt: Date; endsAt: Date };

export type Slot = { start: Date; end: Date };

export function parseHm(value: string): number {
  const [h, m] = value.split(":");
  return Number(h) * 60 + Number(m);
}

/**
 * Gaps of at least `min` minutes inside [windowStart, windowEnd) not covered
 * by any busy range. Busy ranges may overlap, be unsorted, or extend past the
 * window.
 */
export function freeGaps(
  busy: Range[],
  windowStart = DAY_START,
  windowEnd = DAY_END,
  min = MIN_GAP,
): Range[] {
  const clipped = busy
    .filter((r) => r.end > windowStart && r.start < windowEnd)
    .map((r) => ({
      start: Math.max(r.start, windowStart),
      end: Math.min(r.end, windowEnd),
    }))
    .sort((a, b) => a.start - b.start);

  const gaps: Range[] = [];
  let cursor = windowStart;
  for (const r of clipped) {
    if (r.start > cursor) gaps.push({ start: cursor, end: r.start });
    if (r.end > cursor) cursor = r.end;
  }
  if (cursor < windowEnd) gaps.push({ start: cursor, end: windowEnd });
  return gaps.filter((g) => g.end - g.start >= min);
}

/** WIB calendar fields of an instant. */
export function wibParts(instant: Date) {
  const w = new Date(instant.getTime() + WIB_MS);
  return {
    year: w.getUTCFullYear(),
    month: w.getUTCMonth(),
    day: w.getUTCDate(),
    weekday: w.getUTCDay() === 0 ? 7 : w.getUTCDay(), // ISO
    minutes: w.getUTCHours() * 60 + w.getUTCMinutes(),
  };
}

/** Instant for a WIB date + minutes since midnight. */
export function wibInstant(
  year: number,
  month: number,
  day: number,
  minutes: number,
): Date {
  return new Date(Date.UTC(year, month, day) - WIB_MS + minutes * MIN_MS);
}

function entriesOn(entries: Entry[], weekday: number): Range[] {
  return entries
    .filter((e) => e.day_of_week === weekday)
    .map((e) => ({ start: parseHm(e.start_time), end: parseHm(e.end_time) }));
}

/**
 * Free gaps that BOTH people share, Monday to Friday, 07:00 to 17:00 WIB,
 * over the next `days` calendar days starting today. Existing bookings of
 * either person also count as busy. Today's window starts `leadMinutes`
 * from now, rounded up to the next half hour.
 */
export function sharedSlots(opts: {
  now: Date;
  learner: Entry[];
  mentor: Entry[];
  busy?: BusyInstant[];
  days?: number;
  leadMinutes?: number;
  min?: number;
}): Slot[] {
  const { now, learner, mentor } = opts;
  const days = opts.days ?? 7;
  const lead = opts.leadMinutes ?? 60;
  const min = opts.min ?? MIN_GAP;
  const busy = opts.busy ?? [];
  const today = wibParts(now);
  const out: Slot[] = [];

  for (let i = 0; i < days; i++) {
    const date = wibParts(
      wibInstant(today.year, today.month, today.day + i, 12 * 60),
    );
    if (date.weekday > 5) continue;

    let windowStart = DAY_START;
    if (i === 0) {
      const earliest = Math.ceil((today.minutes + lead) / 30) * 30;
      windowStart = Math.max(DAY_START, earliest);
    }
    if (windowStart >= DAY_END) continue;

    const dayStart = wibInstant(date.year, date.month, date.day, 0).getTime();
    const dayEnd = dayStart + 24 * 60 * MIN_MS;
    const booked: Range[] = busy
      .filter((b) =>
        b.endsAt.getTime() > dayStart && b.startsAt.getTime() < dayEnd
      )
      .map((b) => ({
        start: Math.max(0, (b.startsAt.getTime() - dayStart) / MIN_MS),
        end: Math.min(24 * 60, (b.endsAt.getTime() - dayStart) / MIN_MS),
      }));

    const gaps = freeGaps(
      [
        ...entriesOn(learner, date.weekday),
        ...entriesOn(mentor, date.weekday),
        ...booked,
      ],
      windowStart,
      DAY_END,
      min,
    );
    for (const g of gaps) {
      out.push({
        start: wibInstant(date.year, date.month, date.day, g.start),
        end: wibInstant(date.year, date.month, date.day, g.end),
      });
    }
  }
  return out;
}

const DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export function hm(minutes: number): string {
  const h = Math.floor(minutes / 60).toString().padStart(2, "0");
  const m = (minutes % 60).toString().padStart(2, "0");
  return `${h}:${m}`;
}

/** "Tue 12:00" in WIB. */
export function dayTime(instant: Date): string {
  const p = wibParts(instant);
  return `${DAY_NAMES[p.weekday - 1]} ${hm(p.minutes)}`;
}
