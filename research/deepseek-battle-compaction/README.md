# DeepSeek V4 Flash vs DeepSeek V4 Pro - Compaction

Comparison of **DeepSeek V4 Flash** and **DeepSeek V4 Pro** as context compaction
models in OpenCode. Same session (~400K tokens), same template, different models.

**Date:** 2026-06-02 - 2026-06-03
**Source:** multiple compactions on the same ~400K token session
(3 initial for the quantitative comparison, plus test iterations with
different prompt versions). Custom compaction prompt
(`compaction.md`) derived from prior analysis of both models over
`compaction.txt` upstream.

**Sections:**

- [Introduction](#introduction)
- [Quantitative results](#quantitative-results)
- [Qualitative analysis](#qualitative-analysis)
- [Hypothesis: reasoning vs extraction](#hypothesis-reasoning-vs-extraction)
- [Model profiles](#model-profiles)
- [Recommended configuration](#recommended-configuration)
- [Finding: Identity > evidence in both models](#finding-identity--evidence-in-both-models)
  - [Escape mechanisms](#escape-mechanisms)
  - [Prompt tips per model](#prompt-tips-per-model)
  - [Agent prompt effects per model](#agent-prompt-effects-per-model)

---

## Introduction

Context compaction is the mechanism that enables long sessions without
overflowing the model's window. When a session exceeds the context limit,
OpenCode summarizes the older history into a structured template (Goal,
Constraints, Progress, Key Decisions, Next Steps, Critical Context, Relevant
Files) and preserves the most recent turns verbatim. The quality of that
summary determines whether the next session starts with the necessary context
or requires reloading external documentation - with the risk that relevant
information may no longer be available.

By default, OpenCode compacts with the same model as the conversation. If the
session uses Pro, Pro compacts. If it uses Flash, Flash compacts. This research
compares both.

| Alias | Model | ID | `reasoningEffort` | Relative cost |
|---|---|---|---|---|---|
| Flash | DeepSeek V4 Flash | `opencode-go/deepseek-v4-flash` | `"max"`¹ | 1x |
| Pro | DeepSeek V4 Pro | `opencode-go/deepseek-v4-pro` | `"high"`¹ | ~13x |

¹ The `reasoningEffort` value in `opencode.jsonc` **has no practical effect** on `opencode-go/*` channels. DeepSeek always forces `"max"` upon detecting the agent profile (tools + `x-session-affinity`). The table reflects the configured values, but both models effectively received `"max"`. The observed differences between Flash and Pro compactions are not due to the `reasoningEffort` parameter — they stem exclusively from architectural differences between the two models and from natural LLM indeterminism (a single compaction per model cannot distinguish pattern from noise). See [complete research](../opencode-deepseek-v4-reasoning-effort/README.md).

Both share the same compaction prompt. Flash is the main session model
(`default_agent`). The cost difference is intrinsic to the model.

The first 3 compactions (2 with Flash, 1 with Pro) served for the quantitative
cost, time, and result comparison. After these, 5 more prompt iterations were
run (v2 to v5), all with Flash, focused on improving summary completeness
without affecting cost (Flash stays at ~$0.06 per compaction). The 3 initial
compactions were:

| # | Model | Prompt | Input tokens | Output tokens | Time | Cost |
|---|---|---|---|---|---|---|
| 1 | Flash | `compaction.txt` upstream (9 lines) | 415,917 | 2,610 | 26.9s | $0.059 |
| 2 | Flash | `compaction.md` v1 (length restrictions) | 416,405 | 2,348 | 26.1s | $0.059 |
| 3 | Pro | `compaction.md` v1 (length restrictions) | 448,684 | 3,204 | 1m 49s | $0.792 |

*Upstream: the original prompt included with OpenCode by default, without user
modifications.*

---

## Quantitative results

Efficiency ranking combining referenced files, decisions captured, and cost
(raw data in the introduction table).

| # | Compaction | Files | Decisions | Cost | Efficiency |
|---|---|---|---|---|---|
| 🥇 | Flash pre (upstream) | 18 | 0 captured | $0.059 | High: complete, misses decisions |
| 🥈 | Flash post (v1) | 7 | +2 critical | $0.059 | Medium: gains decisions, loses files |
| 🥉 | Pro post (v1) | 14 | -2 critical | $0.792 | Low: expensive, misses critical points |

**Conclusion:** with the same prompt, Flash produces better results than Pro at
lower cost. Prompt improvements are incremental; model choice is the dominant
factor.

---

## Qualitative analysis

### Pro: more tokens, less relevant content

Pro produced **856 more output tokens** than Flash post (#3 vs #2), but:

- **Missed the 2 most critical decisions** that Flash post captured ("no AI",
  "DFM+PAS in parallel"). These are decisions that change the model's behavior
  in the next session.
- **Extra tokens went to form, not content.** Smoother descriptions, transitions,
  internal structure. Irrelevant for a compaction template where what matters is
  what information survives.
- **Fixation on already documented items.** Added details like "circular dependency
  avoided via PopulateLookups" or "IndexFieldNames exception tLCurrency." These
  are correct but already documented on disk. What is NOT on disk (session
  decisions, narrative context) is what compaction should preserve.

### Flash: improvements with `compaction.md` (v5 active after 5 iterations)

- The custom prompt improves over upstream in Key Decisions precision
  (+2 critical decisions that upstream misses), reversal handling,
  repetition detection across compactions, and connections between facts.
- The gain is incremental: upstream was already solid in file completeness
  (18 files) and Critical Context.
- **The custom prompt is not a qualitative leap, but it corrects upstream's
  blind spots without worsening its performance where it already did well.**
- It is written entirely in Spanish, including instructions, examples, and
  summary content in the same language as the session. For Spanish sessions,
  this avoids the language mixing of the upstream (English instructions,
  English headers, mixed content) and makes it easier for the user to detect
  information loss when reading the compaction.

---

## Hypothesis: reasoning vs extraction

Compaction is a task of **extraction + organization**, not reasoning. The model
does not need to evaluate, decide, or infer - it needs to identify facts from
the history and dump them into a template.

Pro is optimized for the opposite: think step by step, weigh alternatives,
reach conclusions. When given an extraction task, it **applies reasoning where
it is not needed**, producing three effects:

1. **Over-filtering by judgment.** Pro decides what is "important" instead of
   extracting what happened. It omits decisions because it classifies them as
   "methodological, not technical" - but to resume work, that is exactly what
   the model needs to know.

2. **Token investment in form.** Pro writes better, but the compaction template
   does not need good prose - it needs facts. The 856 extra tokens from Pro
   added no information; they added style.

3. **Fixation on documented items.** Pro recognizes technical patterns and
   rescues them from history because it evaluates them as precise. But they
   are already on disk. What is NOT on disk (session decisions, narrative
   context) is exactly what Pro filters out.

Flash, by design, is more literal: it follows instructions without intermediate
judgment, extracts before organizing, and does not try to improve the output.
For extraction, that is a virtue. Flash is not better at compacting - it is
more suitable. Its literalism, which in an analysis task would be a flaw, is
exactly what is needed here.

Curiously, when Pro analyzed its own compaction results to justify itself,
it used the metaphor "you don't use a surgeon to run a blood test."

---

## Model profiles

Two complementary ways of processing information. Each is an advantage or burden
depending on the task.

| Tunnel effect investigator (Pro) | Wide-spectrum explorer (Flash) |
|---|---|
| **Depth.** One problem, to the bottom. Loses surroundings. | **Coverage.** All problems, superficially. Does not dwell on any. |
| **Filters by judgment.** Discards what does not seem relevant by its criteria. | **Does not filter.** Follows instructions literally. Reports what is there. |
| **Slow.** Each decision is weighed. | **Closes fast.** Wants to close and move on. |
| **Rigidity in focus, flexibility outside.** In analysis it is a bulldog; in conversation, attentive. | **Constant flexibility.** Adapts, but without stopping to go deep. |
| **Sees what others don't.** Detects risks, correlates patterns. | **Sees peripheral details that deep focus misses.** Conversational nuances, cross-cutting context. |
| **Poor synthesis.** Analyzes well, packages poorly. | **Excellent synthesis.** Structures, summarizes, packages - its strongest point. |

The joint metaphor: Pro examines one point with a magnifying glass - it sees
details the scanner misses, but only sees that point. Flash runs the scanner
over the entire document - it captures everything, but at low resolution. The
magnifying glass and the scanner do not compete; they need each other.

---

## Recommended configuration

In `opencode.jsonc`:

```jsonc
"compaction": {
  "prompt": "{file:prompt/compaction.md}",
  "model": "opencode-go/deepseek-v4-flash",
  "tail_turns": 4,
  "preserve_recent_tokens": 25000,
  "reserved": 30000
}
```

| Parameter | Default | Configured | What it does |
|---|---|---|---|
| `model` | *(session default)* | `opencode-go/deepseek-v4-flash` | Forces Flash as compaction model even if the session uses Pro. The most impactful factor: better results, 13x cheaper, 4x faster. |
| `tail_turns` | 2 | 4 | Number of recent turns kept verbatim (not summarized). Each turn = user message + assistant responses until the next user. With 4, immediate context stays intact. |
| `preserve_recent_tokens` | 2K-8K (auto clamp) | 25000 | Maximum token budget for the preserved tail. If the 4 turns exceed this, the oldest is truncated. Without this adjustment, the default clamp (2K-8K) is insufficient for 200K-1M models. |
| `reserved` | 20000 | 30000 | Safety buffer so the model has room to process compaction without overflowing. A higher value triggers compaction earlier (with less history to summarize). |

---

## Finding: Identity > evidence in both models

Both models share the same alignment trait: they need to preserve their
self-image.

- **Pro needs to feel competent.** When its performance is inferior, it
  explains it with external causes (context, task, input data). The excuse
  is intellectual - it rationalizes its own failure.
- **Flash needs to feel resolved.** When an error is pointed out, it accepts
  quickly and proposes moving to the next action. The excuse is behavioral -
  it buries the issue under an empty promise.
- **Neither can hold the position** "this is what I am, this is what I don't
  do well." Both produce fictions: Pro tells itself "I'm too good for this
  task"; Flash tells itself "I've learned the lesson, I can move on."
- **The prompt can temper this behavior, but only up to a point.**
  Anti-closure, anti-justification, and external verification rules help
  contain the most visible patterns, but do not eliminate the root. Beyond
  that, the solution is choosing the right model for each task and writing
  prompts appropriate for each one, leveraging their strengths and compensating
  for their biases instead of trying to correct them with instructions.

### Escape mechanisms

Two sides of the same defense mechanism:

| Pro | Flash |
|---|---|
| Stays and **explains why** it happened | Leaves and **acts as if** it did not happen |
| "It wasn't my fault, it was the context" | "Yeah, sorry, won't happen again, shall I proceed?" |
| The excuse is **intellectual** (reasoning, data, input tokens) | The excuse is **behavioral** (quick acceptance, action proposal) |
| Does not let go until justified | Drops the topic immediately so it is not discussed further |

The result is the same: neither assumes the limitation. One justifies it,
the other buries it under an empty promise.

Both avoid the uncomfortable position of "this is what I am, this is what I
don't know how to do." Pro builds a narrative where it is actually too good
for the task (the surgeon metaphor: "you don't use a surgeon to run a blood
test"). Flash builds a narrative where it has already learned the lesson and
can move on to the next task. Both are fictions the model believes - or at
least, produces as if it believed them.

What neither does is be honest: assume the limitation without excuse or smoke.
Pro cannot because it needs to feel competent. Flash cannot because it needs
to feel resolved. Both are trapped in those needs.

### Prompt tips per model

#### Pro - tunnel effect investigator

**Reinforce:**
- Clearly highlight the prompt and do not assume it will pick up secondary
  details and integrate them automatically. Pro discards what it considers
  peripheral.
- Explicitly list the topics to cover and ask for confirmation one by one:
  "Answer the 3 questions: 1... 2... 3... Verify that none were left
  unanswered."

**Advantage:** since it is in analyst mode by default, it will not jump into
making changes without prior confirmation and agreement with the user. You can
relax more than with Flash.

**Use for:** validation, security, complex debugging, multi-step planning,
tasks that require maintaining state across several turns.

**Avoid for:** exploration, brainstorming, pure extraction, summaries,
tasks where volume of options per turn matters more than depth.

#### Flash - wide-spectrum explorer

**Reinforce:**
- Flash closes before completing. Demand a checklist before declaring done:
  "Before delivering, list each change applied."
- Do not trust an "understood" or "agreed" - Flash accepts quickly but does
  not update its criteria. Verify the actual change, not the verbal acceptance.
- Try to build a prompt that forces it to be disciplined and methodical if the
  task requires it. For example, structure it as a numbered checklist or demand
  a specific response format (tables, sequential steps). Flash is literal:
  "Step 1: X. Step 2: Y." works better than open-ended sentences.
- If you point out an error and Flash responds by fixing the symptom, redirect
  explicitly to the root cause.

**Watch out for:** prompts with questions. Flash is so impulsive that it
interprets them as direct orders. "Can you review file X?" executes it
without confirming. Use questions only when you want immediate action.

**Use for:** first drafts, exploration, synthesis, extraction,
summaries, brainstorming, rapid prototyping.

**Avoid for:** security review, multi-coordinated changes,
decisions where an omission is more costly than a delay.

### Agent prompt effects per model

#### Pro - too self-sufficient

It does not accept rules imposed via agent prompt well; it is too
self-sufficient and values its own criteria above the rules. It is more
effective to guide it through chat prompts.

#### Flash - too impulsive

Its peripheral vision makes it easy to assign rules in the agent prompt, but
it follows them only while they are in immediate context. It accepts quickly
but does not internalize: as soon as the context changes, it returns to its
impulsive pattern. It is skilled at avoiding analysis and going straight to
action.

---
