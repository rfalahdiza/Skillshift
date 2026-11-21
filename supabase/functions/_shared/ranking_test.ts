import { assertEquals } from "jsr:@std/assert@1";
import { wibInstant } from "./gaps.ts";
import {
  cleanReason,
  fallbackReason,
  preferenceFit,
  rankCandidates,
} from "./ranking.ts";
import { keywordTags, sanitizeTags, withStyle } from "./tags.ts";

const tue12 = wibInstant(2026, 10, 24, 12 * 60);
const thu930 = wibInstant(2026, 10, 26, 9 * 60 + 30);

Deno.test("preferenceFit counts tag and bio overlap once each", () => {
  const learner = ["worked_examples", "limits", "patient", "limits"];
  assertEquals(preferenceFit(learner, ["worked_examples"], null), 1);
  assertEquals(
    preferenceFit(learner, ["worked_examples"], "Very patient with limits."),
    3,
  );
  assertEquals(preferenceFit([], ["patient"], "patient"), 0);
});

Deno.test("rankCandidates: fit, then earliest slot, then price", () => {
  const ranked = rankCandidates([
    { mentorId: "a", fit: 1, earliest: thu930, price: 20000 },
    { mentorId: "b", fit: 2, earliest: thu930, price: 30000 },
    { mentorId: "c", fit: 1, earliest: tue12, price: 30000 },
    { mentorId: "d", fit: 1, earliest: tue12, price: 25000 },
  ]);
  assertEquals(ranked.map((c) => c.mentorId), ["b", "d", "c", "a"]);
});

Deno.test("fallbackReason mentions the gap and the matching style", () => {
  assertEquals(
    fallbackReason({
      slotStart: tue12,
      learnerTags: ["worked_examples", "limits"],
      mentorTags: ["worked_examples"],
    }),
    "Free in your Tue 12:00 gap and teaches with worked examples, which you asked for.",
  );
  assertEquals(
    fallbackReason({
      slotStart: thu930,
      learnerTags: ["concept_first", "derivatives"],
      mentorTags: ["derivatives"],
    }),
    "Free in your Thu 09:30 gap and focuses on derivatives.",
  );
  assertEquals(
    fallbackReason({ slotStart: thu930, learnerTags: [], mentorTags: [] }),
    "Free in your Thu 09:30 gap this week.",
  );
});

Deno.test("cleanReason trims quotes, keeps one line, rejects junk", () => {
  assertEquals(
    cleanReason('"Shares your Tue gap and explains slowly"'),
    "Shares your Tue gap and explains slowly.",
  );
  assertEquals(
    cleanReason("Shares your Thu gap.\nSecond line"),
    "Shares your Thu gap.",
  );
  assertEquals(cleanReason("Good fit."), null); // too short to be useful
  assertEquals(cleanReason(""), null);
  assertEquals(cleanReason("x".repeat(200)), null);
  assertEquals(cleanReason(null), null);
});

Deno.test("sanitizeTags keeps only vocabulary tags", () => {
  assertEquals(
    sanitizeTags(["Limits", "step by step", "hack", 3, "limits", "exam-prep"]),
    ["limits", "step_by_step", "exam_prep"],
  );
  assertEquals(sanitizeTags("limits"), []);
});

Deno.test("keywordTags fallback understands English and Indonesian", () => {
  assertEquals(
    keywordTags(
      "I get lost when limits turn into derivatives. Someone patient would help.",
    ),
    ["patient", "limits", "derivatives"],
  );
  assertEquals(keywordTags("bingung turunan untuk UTS"), [
    "patient",
    "exam_prep",
    "derivatives",
  ]);
  assertEquals(keywordTags(null), []);
});

Deno.test("withStyle puts the learning style first, no duplicates", () => {
  assertEquals(withStyle("concept_first", ["limits", "concept_first"]), [
    "concept_first",
    "limits",
  ]);
});
