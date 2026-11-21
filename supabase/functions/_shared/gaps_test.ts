import { assertEquals } from "jsr:@std/assert@1";
import {
  dayTime,
  type Entry,
  freeGaps,
  parseHm,
  type Range,
  sharedSlots,
  wibInstant,
  wibParts,
} from "./gaps.ts";

const r = (a: string, b: string): Range => ({
  start: parseHm(a),
  end: parseHm(b),
});
const e = (d: number, a: string, b: string): Entry => ({
  day_of_week: d,
  start_time: a,
  end_time: b,
});
/** WIB wall clock → instant. 2026-11-23 is a Monday. */
const at = (day: number, hhmm: string) =>
  wibInstant(2026, 10, day, parseHm(hhmm));
const fmt = (s: { start: Date; end: Date }) =>
  `${dayTime(s.start)}-${dayTime(s.end).split(" ")[1]}`;

Deno.test("freeGaps: empty day is 07:00-17:00", () => {
  assertEquals(freeGaps([]), [r("07:00", "17:00")]);
});

Deno.test("freeGaps: Nadia's Tuesday (L06 design)", () => {
  assertEquals(
    freeGaps([r("07:00", "09:30"), r("10:20", "12:00"), r("13:00", "15:30")]),
    [r("09:30", "10:20"), r("12:00", "13:00"), r("15:30", "17:00")],
  );
});

Deno.test("freeGaps: overlapping, unsorted, out-of-window busy ranges", () => {
  assertEquals(
    freeGaps([
      r("10:00", "11:00"),
      r("06:00", "08:00"),
      r("08:30", "10:15"),
      r("16:30", "19:00"),
    ]),
    [r("08:00", "08:30"), r("11:00", "16:30")],
  );
});

Deno.test("freeGaps: 30 min minimum is inclusive, shorter gaps dropped", () => {
  assertEquals(
    freeGaps([r("07:00", "09:00"), r("09:20", "12:00"), r("12:30", "17:00")]),
    [r("12:00", "12:30")],
  );
});

Deno.test("freeGaps: fully booked day", () => {
  assertEquals(freeGaps([r("06:00", "18:00")]), []);
});

Deno.test("wib helpers round-trip and use ISO weekdays", () => {
  const t = at(24, "12:00"); // Tue 24 Nov 12:00 WIB = 05:00 UTC
  assertEquals(t.toISOString(), "2026-11-24T05:00:00.000Z");
  const p = wibParts(t);
  assertEquals([p.weekday, p.minutes, p.day], [2, 720, 24]);
  assertEquals(wibParts(at(29, "10:00")).weekday, 7); // Sunday
});

Deno.test("sharedSlots: intersection of both timetables, weekdays only", () => {
  // Now: Sunday 22 Nov 20:00 WIB → next 7 days are Mon 23 .. Sat 28.
  const now = at(22, "20:00");
  const learner = [
    e(2, "07:00", "09:30"),
    e(2, "10:20", "12:00"),
    e(2, "13:00", "15:30"),
  ];
  const mentor = [e(2, "07:00", "11:50"), e(2, "13:00", "15:30")];
  const slots = sharedSlots({ now, learner, mentor, days: 7 });
  const tue = slots.filter((s) => wibParts(s.start).weekday === 2).map(fmt);
  assertEquals(tue, ["Tue 12:00-13:00", "Tue 15:30-17:00"]);
  // Mon, Wed, Thu, Fri are fully free for both; Sat/Sun never appear.
  const days = new Set(slots.map((s) => wibParts(s.start).weekday));
  assertEquals([...days].sort(), [1, 2, 3, 4, 5]);
});

Deno.test("sharedSlots: today's window starts after now + lead time", () => {
  // Tuesday 24 Nov, 11:10 WIB. Lead 60 min → earliest 12:30 (rounded up).
  const now = at(24, "11:10");
  const slots = sharedSlots({ now, learner: [], mentor: [], days: 1 });
  assertEquals(slots.map(fmt), ["Tue 12:30-17:00"]);
});

Deno.test("sharedSlots: after 16:00 today has no window", () => {
  const now = at(24, "16:10");
  assertEquals(sharedSlots({ now, learner: [], mentor: [], days: 1 }), []);
});

Deno.test("sharedSlots: existing bookings make people busy", () => {
  const now = at(22, "20:00");
  const learner = [e(2, "07:00", "12:00"), e(2, "13:00", "17:00")];
  const busy = [{ startsAt: at(24, "12:00"), endsAt: at(24, "13:00") }];
  const slots = sharedSlots({ now, learner, mentor: [], busy, days: 3 });
  // Monday is free all day; Tuesday's only gap is already booked.
  assertEquals(slots.map(fmt), ["Mon 07:00-17:00"]);
});

Deno.test("sharedSlots: drops shared gaps under 30 minutes", () => {
  const now = at(22, "20:00");
  const learner = [e(1, "07:00", "09:30"), e(1, "09:50", "17:00")];
  const mentor: Entry[] = [];
  const mon = sharedSlots({ now, learner, mentor, days: 2 });
  assertEquals(mon, []);
});
