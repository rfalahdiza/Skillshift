// Minimal Gemini client. The API key never leaves the server.
// Returns null on any failure so callers can fall back deterministically.

const API = "https://generativelanguage.googleapis.com/v1beta/models";

/** Default when GEMINI_MODEL is not set (stable Flash, verified Nov 2026). */
export const DEFAULT_GEMINI_MODEL = "gemini-3.8-flash";

export function geminiModel(): string {
  return Deno.env.get("GEMINI_MODEL")?.trim() || DEFAULT_GEMINI_MODEL;
}

/**
 * Keep "thinking" as small as each model family allows, so short answers
 * stay fast and cheap. Thinking tokens count toward maxOutputTokens, so
 * models that cannot turn thinking off get a larger output budget.
 */
export function thinkingSettings(
  model: string,
  maxTokens: number,
): { thinkingConfig?: Record<string, unknown>; maxOutputTokens: number } {
  if (/^gemini-2\.5-/.test(model)) {
    // 2.5 Flash / Flash-Lite: thinking can be switched off.
    return model.includes("pro")
      ? { maxOutputTokens: Math.max(maxTokens, 1024) }
      : { thinkingConfig: { thinkingBudget: 0 }, maxOutputTokens: maxTokens };
  }
  if (/^gemini-[3-9]/.test(model) || model.endsWith("-latest")) {
    // Gemini 3+: thinkingLevel; Flash models cannot fully turn it off.
    return {
      thinkingConfig: { thinkingLevel: "low" },
      maxOutputTokens: Math.max(maxTokens, 1024),
    };
  }
  return { maxOutputTokens: Math.max(maxTokens, 1024) };
}

export async function generate(
  prompt: string,
  opts: { json?: boolean; maxTokens?: number; timeoutMs?: number } = {},
): Promise<string | null> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return null;
  const model = geminiModel();

  const generationConfig: Record<string, unknown> = {
    temperature: 0.4,
    ...thinkingSettings(model, opts.maxTokens ?? 120),
  };
  if (opts.json) generationConfig.responseMimeType = "application/json";

  const body = JSON.stringify({
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig,
  });

  // One retry when Google is busy (503) or rate-limits briefly (429).
  for (let attempt = 1; attempt <= 2; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      opts.timeoutMs ?? 12000,
    );
    try {
      const res = await fetch(
        `${API}/${encodeURIComponent(model)}:generateContent`,
        {
          method: "POST",
          signal: controller.signal,
          headers: {
            "content-type": "application/json",
            "x-goog-api-key": key,
          },
          body,
        },
      );
      if (!res.ok) {
        console.warn(`gemini ${model} HTTP ${res.status} (try ${attempt})`);
        if ((res.status === 503 || res.status === 429) && attempt === 1) {
          await new Promise((r) => setTimeout(r, 800));
          continue;
        }
        return null;
      }
      const data = await res.json();
      const parts = data?.candidates?.[0]?.content?.parts;
      if (!Array.isArray(parts)) return null;
      // Skip "thought" parts; keep only the answer text.
      const text = parts
        .filter((p: { thought?: boolean }) => !p.thought)
        .map((p: { text?: string }) => p.text ?? "")
        .join("")
        .trim();
      return text || null;
    } catch (e) {
      console.warn(
        `gemini ${model} failed: ${e instanceof Error ? e.name : e}`,
      );
      return null;
    } finally {
      clearTimeout(timer);
    }
  }
  return null;
}
