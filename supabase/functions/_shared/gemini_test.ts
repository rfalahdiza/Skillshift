import { assertEquals } from "jsr:@std/assert@1";
import { thinkingSettings } from "./gemini.ts";

Deno.test("gemini 2.5 flash turns thinking off with a budget of 0", () => {
  assertEquals(thinkingSettings("gemini-2.5-flash", 60), {
    thinkingConfig: { thinkingBudget: 0 },
    maxOutputTokens: 60,
  });
});

Deno.test("gemini 3.x uses thinkingLevel low and a larger budget", () => {
  for (
    const m of [
      "gemini-3.8-flash",
      "gemini-3.5-flash-lite",
      "gemini-flash-latest",
    ]
  ) {
    assertEquals(thinkingSettings(m, 60), {
      thinkingConfig: { thinkingLevel: "low" },
      maxOutputTokens: 1024,
    });
  }
});

Deno.test("unknown model families get no thinking config", () => {
  assertEquals(thinkingSettings("some-other-model", 60), {
    maxOutputTokens: 1024,
  });
});
