import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

const GEMINI_MODEL = "gemini-3.5-flash-lite";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export default {
  fetch: withSupabase(
    { auth: "publishable" },
    async (req, ctx) => {
      if (req.method === "OPTIONS") {
        return new Response("ok", {
          headers: corsHeaders,
        });
      }

      try {
        const body = await req.json();

        const {
          title,
          topic,
          difficulty,
          mode,
          notes = "",
          question,
          answer,
          user_context,
        } = body;

        if (
          typeof title !== "string" ||
          typeof topic !== "string" ||
          typeof difficulty !== "string" ||
          typeof mode !== "string"
        ) {
          return Response.json(
            { error: "Invalid request." },
            {
              status: 400,
              headers: corsHeaders,
            },
          );
        }

        const allowedModes = [
          "hint1",
          "hint2",
          "approach",
          "interview_question",
          "interview_feedback",
          "motivation",
        ];

        if (!allowedModes.includes(mode)) {
          return Response.json(
            { error: "Invalid AI mode." },
            {
              status: 400,
              headers: corsHeaders,
            },
          );
        }

        const apiKey = Deno.env.get("GEMINI_API_KEY");

        if (!apiKey) {
          console.error("GEMINI_API_KEY is not configured.");

          return Response.json(
            {
              error: "AI service is not configured.",
            },
            {
              status: 500,
              headers: corsHeaders,
            },
          );
        }

        const prompt = buildPrompt({
          title,
          topic,
          difficulty,
          mode,
          notes,
          question: typeof question === "string" ? question : undefined,
          answer: typeof answer === "string" ? answer : undefined,
          userContext: isPlainObject(user_context) ? user_context : null,
        });

        const geminiResponse = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": apiKey,
            },
            body: JSON.stringify({
              contents: [
                {
                  parts: [
                    {
                      text: prompt,
                    },
                  ],
                },
              ],
              generationConfig: {
                temperature: 0.25,
                maxOutputTokens: 350,
              },
            }),
          },
        );

        if (!geminiResponse.ok) {
          const errorText = await geminiResponse.text();

          console.error(
            "Gemini API error:",
            geminiResponse.status,
            errorText,
          );

          return Response.json(
            {
              error: "AI request failed.",
            },
            {
              status: 502,
              headers: corsHeaders,
            },
          );
        }

        const data = await geminiResponse.json();

        const text =
          data?.candidates?.[0]?.content?.parts?.[0]?.text;

        if (!text) {
          return Response.json(
            {
              error: "AI returned an empty response.",
            },
            {
              status: 502,
              headers: corsHeaders,
            },
          );
        }

        return Response.json(
          {
            text: cleanAiResponse(text.toString()),
            mode,
          },
          {
            headers: corsHeaders,
          },
        );
      } catch (error) {
        console.error("AI Coach error:", error);

        return Response.json(
          {
            error: "Something went wrong with AI Coach.",
          },
          {
            status: 500,
            headers: corsHeaders,
          },
        );
      }
    },
  ),
};

function buildPrompt({
  title,
  topic,
  difficulty,
  mode,
  notes,
  question,
  answer,
  userContext,
}: {
  title: string;
  topic: string;
  difficulty: string;
  mode: string;
  notes: string;
  question?: string;
  answer?: string;
  userContext: Record<string, unknown> | null;
}) {
  const userContextText = formatUserContext(userContext);

  const base = `
You are the AI Coach inside Min's Prep, a coding interview preparation app.

Problem:
Title: ${title}
Topic: ${topic}
Difficulty: ${difficulty}

Student notes:
${notes || "(No notes yet)"}

${userContextText}

STRICT RULES:
- Teach the student instead of immediately solving the problem.
- Never provide code.
- Never provide the complete solution during a hint.
- Do not invent constraints, examples, inputs, or outputs.
- Do not start with a greeting or introduction.
- Never mention Neo 150 Prep.
- Never mention yourself as an AI.
- Do not ask follow-up questions.
- Do not end with a question.
- Do not add motivational filler.
- Use the USER CONTEXT only when relevant to the current problem or coaching advice.
- Do not invent user statistics or data that are not in the USER CONTEXT.
- If a context value is missing, ignore it.
- Return only the requested content.
`;

  switch (mode) {
    case "hint1":
      return `${base}

MODE: FIRST HINT

Give exactly one subtle hint.
The student should still need to discover the algorithmic pattern.
Keep it to 2-3 concise sentences.
Do not use headings.
`;

    case "hint2":
      return `${base}

MODE: SECOND AND FINAL HINT

The student has already received one hint.
Give exactly one stronger hint that points toward the core algorithmic idea or data structure.
Do not give the complete solution or all implementation steps.
Keep it to 2-4 concise sentences.
Do not use headings.
`;

    case "approach":
      return `${base}

MODE: APPROACH

Explain the high-level approach in a clean, interview-prep-friendly format.

Return EXACTLY these five sections, in EXACTLY this order:

PATTERN
One short line naming the main algorithmic pattern or data structure.

CORE IDEA
2-4 concise sentences explaining the central insight.

HOW IT WORKS
3-5 short steps, one step per line. Start each step with a number such as 1. 2. 3. Do not use bullets.

TIME COMPLEXITY
One concise line such as O(n), followed by a short reason. Use the exact notation O(n), not "O of n".

SPACE COMPLEXITY
One concise line such as O(1) or O(n), followed by a short reason. Use exact Big-O notation.

Formatting rules:
- Use the section names exactly as written.
- Put each section name on its own line.
- Always write time and space complexity using canonical Big-O notation:
  O(1), O(n), O(log n), O(n log n), O(n²), O(m + n), etc.
- Never write complexity as "O of n", "O of 1", "O of log n", or similar prose.
- Keep the complexity expression on the same line as its reason.
- Do not use Markdown bold, italics, backticks, or # headings.
- Do not add an introduction before PATTERN.
- Do not add a conclusion after SPACE COMPLEXITY.
- Do not ask a question.
`;

    case "interview_question":
      return `${base}

MODE: INTERVIEW QUESTION

Generate exactly one interview-style question for this problem.
Keep it focused on the problem's core thinking and communication.
Do not provide the answer.
Do not ask follow-up questions.
Return only the question text.
`;

    case "interview_feedback":
      return `${base}

MODE: INTERVIEW FEEDBACK

The student answered the question below.
Question: ${question ?? title}

Student answer:
${answer ?? "(No answer provided)"}

Give concise interview feedback in a realistic, coaching tone.
Focus on clarity, structure, correctness, and how to improve.
Use a score in the format: Score: X/10.
Do not provide code.
Do not give the complete solution.
Do not add a greeting or a conclusion.
Return only the feedback.
`;

    case "motivation":
      return `You are Min, the quiet observer inside a coding interview preparation app.

The user just made meaningful progress. Write a SHORT, PERSONAL acknowledgment.

STRICT RULES:
- 1-3 sentences maximum
- Warm, observant, personal tone
- Slightly playful when appropriate
- Honest without being cheesy
- Reference ONLY the facts explicitly provided below
- Do NOT fabricate statistics, streaks, achievements, or behavior
- Do NOT infer session counts from daily or total counts
- Do NOT describe behavior that isn't explicitly present in the facts
- Do NOT claim improvement unless improvement data is explicitly supplied
- Do NOT give generic motivational speeches
- Do NOT mention being an AI
- Do NOT use excessive emojis (max 1-2 if any)
- Do NOT give study advice
- Do NOT start with greetings like "Great job!" or "Congratulations!"
- Focus on the specific remarkable progress
- If a fact is missing, ignore it
- If there isn't enough context for a meaningful acknowledgment, keep it simple

IMPORTANT FACT DISTINCTIONS:
- "completed_today" = problems completed today (all day)
- "session_completed" = problems completed in this session (recent activity)
- "total_completed" = total problems completed ever
- These are DIFFERENT counts. Never confuse them.

USER PROGRESS FACTS:
${notes || "No specific progress data provided."}

Return only the acknowledgment text.
`;

    default:
      return base;
  }
}

function formatUserContext(userContext: Record<string, unknown> | null): string {
  if (!userContext || Object.keys(userContext).length === 0) {
    return "USER CONTEXT:\nNone provided.";
  }

  const sections: string[] = ["USER CONTEXT:"];

  for (const [key, value] of Object.entries(userContext)) {
    if (value === null || value === undefined) continue;
    sections.push(`${key}: ${JSON.stringify(value, null, 2)}`);
  }

  return sections.join("\n");
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function cleanAiResponse(text: string): string {
  return text
    .trim()
    .replace(/^\s*#+\s*/gm, "")
    .replace(/\*\*/g, "")
    .replace(/`{1,3}/g, "")
    .trim();
}
