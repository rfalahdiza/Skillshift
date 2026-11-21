// Rule-based ranking for match-mentors. Pure functions, unit-tested.

import { dayTime } from "./gaps.ts";

/** How many learner tags the mentor covers (tags or bio wording). */
export function preferenceFit(
  learnerTags: string[],
  mentorTags: string[],
  bio: string | null | undefined,
): number {
  const mentor = new Set(mentorTags.map((t) => t.toLowerCase()));
  const text = (bio ?? "").toLowerCase();
  let score = 0;
  for (const tag of new Set(learnerTags.map((t) => t.toLowerCase()))) {
    const words = tag.replace(/_/g, " ");
    if (mentor.has(tag) || (words.length > 3 && text.includes(words))) {
      score++;
    }
  }
  return score;
}

export type Candidate = {
  mentorId: string;
  fit: number;
  earliest: Date;
  price: number;
};

/**
 * Order: preference fit (high first), then earliest shared slot, then price
 * (low first). Mentor id breaks ties so results are deterministic.
 */
export function rankCandidates<T extends Candidate>(items: T[]): T[] {
  return [...items].sort((a, b) =>
    b.fit - a.fit ||
    a.earliest.getTime() - b.earliest.getTime() ||
    a.price - b.price ||
    a.mentorId.localeCompare(b.mentorId)
  );
}

const STYLE_PHRASES: Record<string, string> = {
  worked_examples: "teaches with worked examples",
  concept_first: "explains the concept first",
  practice_together: "runs practice-heavy sessions",
};

/** Deterministic one-line reason, used whenever Gemini fails. */
export function fallbackReason(opts: {
  slotStart: Date;
  learnerTags: string[];
  mentorTags: string[];
}): string {
  const when = `Free in your ${dayTime(opts.slotStart)} gap`;
  const style = opts.learnerTags.find((t) => STYLE_PHRASES[t]);
  if (style && opts.mentorTags.includes(style)) {
    return `${when} and ${STYLE_PHRASES[style]}, which you asked for.`;
  }
  const shared = opts.learnerTags.find(
    (t) => !STYLE_PHRASES[t] && opts.mentorTags.includes(t),
  );
  if (shared) return `${when} and focuses on ${shared.replace(/_/g, " ")}.`;
  return `${when} this week.`;
}

/** Accept a Gemini sentence only if it is short and clean. */
export function cleanReason(text: string | null | undefined): string | null {
  if (!text) return null;
  let s = text.trim().split("\n")[0].trim();
  s = s.replace(/^["'“”]+|["'“”]+$/g, "").trim();
  if (s.length < 10 || s.length > 160) return null;
  if (!/[.!]$/.test(s)) s += ".";
  return s;
}
