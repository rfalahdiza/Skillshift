// Minimal Gemini client. The API key never leaves the server.
// Returns null on any failure so callers can fall back deterministically.

const API = "https://generativelanguage.googleapis.com/v1beta/models";

export function geminiModel(): string {
  return Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-2.5-flash";
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
    maxOutputTokens: opts.maxTokens ?? 120,
  };
  if (opts.json) generationConfig.responseMimeType = "application/json";
  // Flash models: skip "thinking" so short answers stay fast and cheap.
  if (model.includes("flash")) {
    generationConfig.thinkingConfig = { thinkingBudget: 0 };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? 8000);
  try {
    const res = await fetch(
      `${API}/${encodeURIComponent(model)}:generateContent`,
      {
        method: "POST",
        signal: controller.signal,
        headers: { "content-type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig,
        }),
      },
    );
    if (!res.ok) {
      console.warn(`gemini ${model} HTTP ${res.status}`);
      return null;
    }
    const data = await res.json();
    const parts = data?.candidates?.[0]?.content?.parts;
    if (!Array.isArray(parts)) return null;
    const text = parts.map((p: { text?: string }) => p.text ?? "").join("")
      .trim();
    return text || null;
  } catch (e) {
    console.warn(`gemini ${model} failed: ${e instanceof Error ? e.name : e}`);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
