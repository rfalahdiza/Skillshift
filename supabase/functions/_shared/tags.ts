// Preference tag vocabulary shared by learners (quiz) and mentors (profile).
// A fixed vocabulary keeps rule-based matching predictable: Gemini may only
// pick from this list, and a keyword fallback covers Gemini failures.

export const LEARNING_STYLES = [
  "worked_examples",
  "concept_first",
  "practice_together",
] as const;
export type LearningStyle = (typeof LEARNING_STYLES)[number];

export const TAG_VOCABULARY = [
  ...LEARNING_STYLES,
  "patient",
  "step_by_step",
  "visual",
  "exam_prep",
  "coding",
  "debugging",
  "limits",
  "derivatives",
  "integrals",
  "physics",
  "logic",
  "databases",
  "data_structures",
  "proofs",
] as const;

const VOCAB = new Set<string>(TAG_VOCABULARY);

/** Keywords (English and Indonesian) for the no-AI fallback. */
const KEYWORDS: Record<string, string[]> = {
  patient: ["patient", "sabar", "slow", "pelan", "lost", "confus", "bingung"],
  step_by_step: ["step", "langkah", "detail", "small steps"],
  visual: ["visual", "diagram", "draw", "gambar", "graph", "grafik"],
  exam_prep: [
    "exam",
    "uts",
    "uas",
    "midterm",
    "final",
    "ujian",
    "quiz",
    "kuis",
  ],
  coding: [
    "code",
    "coding",
    "program",
    "loop",
    "array",
    "function",
    "python",
    "java",
    "c++",
  ],
  debugging: ["debug", "error", "bug"],
  limits: ["limit"],
  derivatives: ["derivative", "turunan", "differenti"],
  integrals: ["integral"],
  physics: ["physics", "fisika", "force", "gaya", "motion", "gerak"],
  logic: ["logic", "logika", "boolean"],
  databases: ["database", "basis data", "sql", "query", "erd"],
  data_structures: [
    "tree",
    "graph",
    "stack",
    "queue",
    "linked list",
    "struktur data",
  ],
  proofs: ["proof", "bukti", "induction", "induksi"],
};

/** Keep only known tags, lowercase, unique, at most `max`. */
export function sanitizeTags(raw: unknown, max = 6): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const t of raw) {
    if (typeof t !== "string") continue;
    const tag = t.trim().toLowerCase().replace(/[\s-]+/g, "_");
    if (VOCAB.has(tag) && !out.includes(tag)) out.push(tag);
    if (out.length >= max) break;
  }
  return out;
}

/** Rule-based tags from the open answer (used when Gemini fails). */
export function keywordTags(
  text: string | null | undefined,
  max = 6,
): string[] {
  const value = (text ?? "").toLowerCase();
  const out: string[] = [];
  for (const [tag, words] of Object.entries(KEYWORDS)) {
    if (words.some((w) => value.includes(w))) out.push(tag);
    if (out.length >= max) break;
  }
  return out;
}

/** The learning style is always the first tag. */
export function withStyle(style: LearningStyle, tags: string[]): string[] {
  return [style, ...tags.filter((t) => t !== style)].slice(0, 7);
}

export function isLearningStyle(v: unknown): v is LearningStyle {
  return typeof v === "string" &&
    (LEARNING_STYLES as readonly string[]).includes(v);
}
