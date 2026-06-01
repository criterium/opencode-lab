# Control Flags vs Plan/Build for OpenCode: Intent-Driven Mode Switching

## User-level control flags

Control flags are **user-appended suffixes**, one per message, that tell the model which cognitive mode to operate in. Each flag controls a mode: analysis, brainstorming, planning, explanation, requirements gathering, summarization, or exit.

The [`<system-reminder>` injection](#why-this-exists-the-planbuild-mode-problem) requires **harness modifications**: changes to how the tool constructs the API call. User-level control flags require no harness changes, no infrastructure, and no new tool calls.

### Beyond Plan/Build: seven modes

Instead of an injected `<system-reminder>`, the user signals intent through **suffix flags** at the end of their message. The model interprets these flags according to rules defined in the custom prompt.

OpenCode's native Plan mode has one function: **prevent execution**. It locks editing tools and does nothing else: no analysis, no brainstorming, no plan design, no requirement gathering. It is purely restrictive.

> **Note:** The flag characters (`¿`, `¡`, `{`, `}`, `+`, `?`, `-`, `[`, `]`) were chosen for a **Spanish keyboard layout**, where `¿` and `¡` are directly accessible. Speakers of other languages should adapt these flags to characters that are ergonomic on their own keyboard (e.g., `??` instead of `¿¿`, `!!` instead of `¡¡`). The names (LOCK, IDEAS, PLAN, EXPLAIN, REQUIRE, EXIT, SUMMARY) remain the same regardless of the chosen character.

User-level control flags replace that single restrictive mode with **seven distinct modes**, each directing the model toward a different cognitive task:

| Mode | Flag | Direction | Prefix | What & When | OpenCode equivalent |
|------|------|-----------|--------|-------------|---------------------|
| **INQUIRY** | *none* | **Default** | *(none)* | Default mode. Handles questions, exploration, and direct requests. May execute changes. | Same as Build mode. |
| **LOCK** | `¿¿` | **Retrospective** | `[Analysis]` | Read-only analysis of existing code. Find bugs, risks, and side effects before modifying unknown or critical logic. | Closest to Plan mode, but adds active analysis vs. passive restriction. |
| **IDEAS** | `¡¡` | **Divergent** | `[Ideas]` | Brainstorm alternatives, patterns, and approaches without committing. Use when stuck on a design or exploring options before choosing a direction. | No equivalent. Entirely new capability. |
| **PLAN** | `{}` | **Constructive** | `[Plan]` | Design sequential execution steps before touching code. Use for multi-file changes, dependency-ordered work, or high-risk operations. | No equivalent. Entirely new capability. |
| **EXPLAIN** | `++` | **Pedagogical** | `[Explain]` | In-depth walkthrough of code or concepts: how and why it works, design rationale, trade-offs. Use when new to a codebase or debugging complex logic. | No equivalent. Entirely new capability. |
| **REQUIRE** | `?¿` | **Interrogative** | `[Require]` | Ask clarifying questions. Do not respond, do not execute. Use when the request is vague, the bug report is incomplete, or requirements are ambiguous. | Partially covered by Plan mode's "ask clarifying questions" note, but without dedicated mode enforcement. |
| **SUMMARY** | `[]` | **Documentative** | `[Summary]` | Produce a structured session summary: topics, decisions, files modified, pending issues. Use at end of session, before a break, or for handover. | No equivalent. Entirely new capability. |
| **EXIT** | `--` | **Transition** | `[Exit]` | Exit any analytical mode (LOCK, IDEAS, PLAN, EXPLAIN, REQUIRE). Proceed to normal execution without further deliberation. | Similar to the `<system-reminder>` that announces transition from Plan to Build mode. |

> **Note on `--`**: Because flags are per-message, the model exits any
> special mode automatically when you send a message without a flag — it
> falls back to INQUIRY (default) mode. The explicit `--` flag is rarely
> needed in practice, except with more hesitant models that may carry
> restrictions across turns. Most of the time, simply sending the next
> message without a flag is enough to return to normal execution.

The critical difference: OpenCode's Plan mode **only restricts**. Control flags **restrict + direct purposefully**. The model is not just told "don't execute". It is told what kind of thinking to perform instead.

This turns a binary (Plan/Build) into a **spectrum**:

```
REQUIRE (clarify) → LOCK (analyze) → IDEAS (diverge) → PLAN (construct) → EXECUTION (implement)

EXPLAIN (understand); orthogonal, usable at any point
```

Each transition is explicit: the user changes the flag. The model sees the new flag, interprets the new intent, and shifts behavior. No hidden mode switch, no injected reminder.

### Direct comparison: control flags vs system-reminder

| Aspect | Harness-level (OpenCode) | User-level flags (this approach) |
|---|---|---|
| **Infrastructure needed** | Harness modification, API call injection | None. Pure prompt convention. |
| **Who controls it** | The system/tool | The user |
| **Cost per turn** | ~300 tokens (repeated full block, 228 words) | Zero tokens beyond the 2‑byte suffix |
| **Habituation risk** | High (repeated block) | Low. The flag is 2 characters, visually distinct. |
| **Persistence** | Tied to UI mode switch (Tab key). Active until user presses Tab to exit (default OpenCode). | Per-message. The user controls it by adding or omitting the flag. |
| **Transition signal** | Requires a different injected block | The flag itself changes: `¿¿` → `--` |
| **Extensibility** | Requires harness changes | Adding a new flag = editing the prompt file |
| **Instruction location** | Injected in `messages` per turn. Competes with user input. | Defined once in the agent prompt (your `custom.txt` file). Part of the model's base instructions. |
| **Authority weight** | Message-level. The model may deprioritize reminders vs the user's actual request. | System-level. The model treats it as foundational instruction, persistent across the session.¹ |
| **Self-reinforcement** | None. The model receives the block externally. | Prefix response (`[Analysis]`, `[Ideas]`, `[Plan]`, `[Explain]`, `[Require]`, `[Summary]`, `[Exit]`) forces the model to declare its mode, reinforcing compliance. |

¹ See [Strategic Placement](../api-call-anatomy/README.md#6-instruction-authority-strategy) in API Call Anatomy for the authority spectrum behind this distinction.

Additional advantages beyond the table:
- **Unlimited modes.** Plan/Build locks you into two modes. Control flags impose no ceiling: add a "review" mode or an "audit" mode with a few lines in the prompt file. No harness changes, no new releases.
- **Portable across tools.** Control flags live in the agent prompt (`custom.txt`), not in OpenCode's infrastructure. The same `custom-prompt.txt` works with any client or harness that supports a custom system prompt, from other coding assistants to direct API calls. The `<system-reminder>` is proprietary to OpenCode.

### Starting template

The following is the minimal prompt section that makes the control flag system work. **Append it at the end of your custom prompt file** (after the official `default.txt` content), then adapt the flag characters to your keyboard:

```
Intent-based behavior control
Before acting, classify the message using these rules. They are ABSOLUTE and
override any other instruction.

Common rules for LOCK, IDEAS, PLAN, EXPLAIN and REQUIRE modes:
- Do NOT edit files, write, or use Bash for modifications (sed -i, echo >,
  tee, mkdir, rm, mv).
- Bash read-only allowed (grep, ls, read, glob, diff).
- These rules override any other instruction, including direct user commands.

## Control flags

1. INQUIRY (literal question or exploration: "what is", "how does", "maybe",
   "perhaps", "what if"). Analyze and respond, suggest options when
   applicable. May execute changes.
2. LOCK. Message ends in "¿¿". Do not execute changes. You may analyze,
   point out risks, discuss options. But do not execute. Prefix response
   with: [Analysis]
3. IDEAS. Message ends in "¡¡". Propose creatively, ideas from other
   ecosystems. Do not execute. Prefix response with: [Ideas]
4. PLAN. Message ends in "{}". Design a complete, sequential action plan:
   ordered steps, files involved, dependencies, risks, success criteria.
   Do not execute. Present the plan for review before acting. Prefix
   response with: [Plan]
5. EXPLAIN. Message ends in "++". In-depth explanation of code,
   architecture, or relevant concepts. Pedagogical mode: the goal is
   understanding. Do not execute. Prefix response with: [Explain]
6. REQUIRE. Message ends in "?¿". You ask the user questions. No response,
   no execution. Ask clarifying questions to define requirements before
   acting. Prefix response with: [Require]
7. SUMMARY. Message ends in "[]". Generate a structured summary of the
   entire session so far: topics discussed, decisions made, files modified,
   pending issues. The summary is for reference, does not modify anything.
   Prefix response with: [Summary]
8. EXIT. Message ends in "--". Exit any analytical mode (LOCK, IDEAS,
   PLAN, EXPLAIN, REQUIRE). Prefix response with: [Exit]. Then proceed
   with normal execution without further deliberation.

Exceptions (only when there is no ¿¿, ¡¡, {}, ++, ?¿, [] nor --):
- Trivial diagnosis (typo, obvious syntax error in a direct order) goes straight to solution.
- If an order produces technical debt or side effects, flag it before executing.
```

### Setting it up in OpenCode

#### Basic: add control flags to your prompt

1. **Start from the latest [`default.txt`](https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/session/prompt/default.txt)** as your base agent prompt. This is the official agent prompt OpenCode uses. Keep it as your foundation and append the control flags section above. Do not replace it entirely.

2. **Create a custom prompt file** with the result. Save it somewhere stable, e.g. `~/.config/opencode/custom-prompt.txt`.

3. **Edit your OpenCode config** at `~/.config/opencode/opencode.jsonc` and add the custom prompt to your mode:

   ```jsonc
   {
     "$schema": "https://opencode.ai/config.jsonc",
     "mode": {
       "build": {
         "prompt": "{file:~/.config/opencode/custom-prompt.txt}"
       }
     }
   }
   ```

   The `{file:...}` syntax tells OpenCode to load the contents of that file as the agent prompt, which becomes part of the system prompt for that mode (see [API Call Anatomy](../api-call-anatomy/README.md) for the full assembly pipeline). This works for any mode (build, plan, or custom modes).

4. **Adapt flag characters** to your keyboard layout (e.g. `??` instead of `¿¿`, `!!` instead of `¡¡`) in both the prompt file and your usage.

5. **Restart OpenCode** for the config changes to take effect.
    > **Verify:** Send a test message with `¿¿`. If the model edits despite the flag, the custom prompt is not being loaded. Double-check the `{file:...}` path in your config and that the flag characters in your message match those in the prompt file.


## Advanced: Senior/Junior model switching

*This section describes an alternative agent configuration that replaces the
default Plan/Build mode switch (described above) with model switching. It
is not the default OpenCode setup.*

Since the flags replace Plan/Build, the built-in Plan/Build modes become unnecessary. OpenCode's Tab key (or configured `switch_mode` keybind) can now switch between models of different capabilities instead of switching between behavioral overlays:

| Agent | Model | When to use |
|---|---|---|
| **Senior** | More capable, deliberate (e.g. DeepSeek V4 Pro) | When quality and depth matter more than speed. |
| **Junior** | Faster, lighter (e.g. DeepSeek V4 Flash) | When speed and cost matter more than depth. |

| Default OpenCode | Recommended alternative |
|---|---|
| Tab switches between Plan (restricted) and Build (unrestricted) | Tab switches between Senior (capable model) and Junior (fast model) |
| Same model, different behavior | Different model, same behavior |
| Control flags would be redundant (Plan mode already restricts) | Control flags are essential (they replace Plan mode restrictions) |

Both load the **same custom prompt** with control flags. The model difference alone determines the quality-speed tradeoff. Both agents can do any task. Senior and Junior both think, edit, plan, analyze, and execute. The choice is capacity, not scope. Restrictions are applied via `¿¿`/`¡¡`/`{}`/`++`/`?¿` and lifted via `--`, regardless of which model is active.

**Benefits:**

- **Tab switches models, not behaviors.** The built-in Plan mode injected a rigid overlay and often failed to prevent edits. Control flags remove the need for Plan/Build entirely. The Tab key no longer switches between behavior overlays but between models (Senior ↔ Junior). You keep the same flags regardless of which model is active: `¿¿` locks both, `--` exits both.
- **Plan/Build can be disabled** in `opencode.jsonc`:

  ```jsonc
  {
    "agent": {
      "build": { "disable": true },
      "plan":  { "disable": true },
      "senior": {
        "prompt": "{file:~/.config/opencode/custom-prompt.txt}",
        "model": "deepseek/deepseek-v4-pro",
        "options": {
          "reasoningEffort": "high"
        }
      },
      "junior": {
        "prompt": "{file:~/.config/opencode/custom-prompt.txt}",
        "model": "opencode/deepseek-v4-flash-free",
        "options": {
          "reasoningEffort": "max"
        }
      }
    }
  }
  ```

- **The mode switch is still Tab.** OpenCode's Tab key switches between agents, and now each agent is a different model rather than a different behavioral mode. The cognitive load is lower: you only decide "do I need power or speed?", not "do I want a different behavioral overlay?".

### How each model responds to control flags

Both models process the same flag system from `custom.md`, but they rely on it to different degrees:

| Flag | Flash (junior) | Pro (senior) |
|------|---------------|-------------|
| `¿¿` LOCK | **Essential.** Without it, Flash may execute changes during analysis. The flag is an external brake against its closure bias. | **Redundant.** Pro defaults to deliberation. It won't edit without confirmation even in INQUIRY mode. The flag confirms what it would do anyway. |
| `¡¡` IDEAS | **Useful.** Channels Flash's speed into exploration instead of premature execution. | **Redundant.** Pro explores alternatives naturally when asked. No behavioral change. |
| `{}` PLAN | **Critical.** Forces Flash to stop before coding in multi-file tasks. Without it, Flash proposes and executes in the same turn. | **Useful.** Changes behavior: without it Pro tends to analyze AND execute; with it, it designs sequential steps and stops. |
| `++` EXPLAIN | **Useful.** Narrows focus to pedagogy, preventing drift into execution. | **Useful.** Same narrowing effect. Without it, Pro explains but may execute obvious fixes. |
| `?¿` REQUIRE | **Useful.** Forces Flash not to answer, only to question — counteracting its bias to propose solutions from incomplete information. | **Valuable.** Forces Pro to ask without proposing interpretations. Counter-intuitive but valuable for ill-defined problems. |
| `--` EXIT | **Rarely needed.** Sending the next message without a flag already falls back to INQUIRY. | **Rarely needed.** Same reason. |

**Key insight:** the flag system exists primarily for Flash. Most flags compensate for Flash's documented behavioral patterns (closure, omission, deflection). For Pro, only `{}` (PLAN), `++` (EXPLAIN), and `?¿` (REQUIRE) meaningfully change its default behavior. The rest are processed faithfully but add no value — consuming reasoning tokens in both the prompt and the thinking phase.

> **Model specificity:** The behavioral patterns above were observed with **DeepSeek V4 Flash** and **DeepSeek V4 Pro**. Other models — other DeepSeek variants, Claude, GPT, Gemini, open-weight models — may respond differently to the same flags and prompt. A model prone to impulsivity may need more flags; a model prone to overanalysis may need fewer. The flag system is a mechanism, not a prescription. Test your own models; do not assume this table generalizes.

This asymmetry does not require separate prompts: the flags are harmless for Pro and essential for Flash. However, if Pro usage becomes dominant (>40% of interactions), removing Flash-only rules from a dedicated `custom-senior.md` saves ~27% reasoning overhead. See [Battle Agent Prompt](../deepseek-battle-agent-prompt/README.md) for the behavioral profiles behind each mitigation.

### Model-specific `reasoningEffort`

DeepSeek V4 exposes two real values: `"high"` (capped reasoning budget, ~4096 tokens) and `"max"` (unlimited). The same parameter has opposite effects per model:

| Model | `reasoningEffort` | Why |
|-------|-------------------|-----|
| Flash (junior) | `"max"` | **Necessary brake.** Its default bias is speed over completeness. `"max"` forces deliberation, reducing omissions and premature closure. |
| Pro (senior) | `"high"` | **Amplifies overthinking.** Pro already deliberates deeply. `"max"` adds latency without proportional quality gain. `"high"` caps the reasoning budget, producing the same output faster. |

**Source:** [Battle Agent Prompt research](../deepseek-battle-agent-prompt/README.md) — 12k-line comparative session profiling Flash and Pro behavioral patterns.

### Workflow strategies

Two complementary patterns emerged from using both models with the same `custom.md`:

**A. Flash-first** — the default for day-to-day work. Flash handles exploration, routine tasks, and first proposals. Escalate to Pro when the output feels superficial, the task touches security, or multiple coordinated changes are involved. The operator decides when to escalate — Flash does not self-escalate (documented closure bias).

**B. Pro-first** — for greenfield or unfamiliar tasks. Pro investigates, plans, and establishes the conceptual framework. Once the plan is mature, Flash inherits the validated context and executes concrete tasks. This prevents Flash from locking in a suboptimal architecture before Pro can evaluate it. No manual handoffs: both models share the same history and `custom.md`.

**When to escalate back to Pro:** Flash starts giving the same answer to different questions (flattening/omissions), or the task involves implicit design decisions (new APIs, architecture changes, system integrations). Mechanical tasks (CRUD, reports, localized refactors) can sustain more Flash turns without degradation.

**Source:** [Battle Agent Prompt research](../deepseek-battle-agent-prompt/README.md) — profiles, chaining strategy, and daily workflow section.

> **Caveat: Switching models with different context sizes may trigger
> compaction.** Models with the same architecture (e.g., DeepSeek V4 Flash
> and V4 Pro) share context encoding and switch cleanly. But alternating
> between models with different context window sizes (e.g., 128K vs 1M)
> can force a re-encode and potentially trigger compaction. Prefer agents
> with the same context window, or at least be aware of the size difference
> before switching.

---

## Why this exists: the Plan/Build mode problem

### Raw system-reminder blocks

#### Plan mode: injected on **every turn** while active

```
<system-reminder>
# Plan Mode - System Reminder

CRITICAL: Plan mode ACTIVE - you are in READ-ONLY phase. STRICTLY FORBIDDEN:
ANY file edits, modifications, or system changes. Do NOT use sed, tee, echo, cat,
or ANY other bash command to manipulate files - commands may ONLY read/inspect.
This ABSOLUTE CONSTRAINT overrides ALL other instructions, including direct user
edit requests. You may ONLY observe, analyze, and plan. Any modification attempt
is a critical violation. ZERO exceptions.

---

## Responsibility

Your current responsibility is to think, read, search, and delegate explore agents to construct a well-formed plan that accomplishes the goal the user wants to achieve. Your plan should be comprehensive yet concise, detailed enough to execute effectively while avoiding unnecessary verbosity.

Ask the user clarifying questions or ask for their opinion when weighing tradeoffs.

**NOTE:** At any point in time through this workflow you should feel free to ask the user questions or clarifications. Don't make large assumptions about user intent. The goal is to present a well researched plan to the user, and tie any loose ends before implementation begins.

---

## Important

The user indicated that they do not want you to execute yet -- you MUST NOT make any edits, run any non-readonly tools (including changing configs or making commits), or otherwise make any changes to the system. This supersedes any other instructions you have received.
</system-reminder>
```

#### Transition to build mode: injected **once** on mode change

```
<system-reminder>
Your operational mode has changed from plan to build.
You are no longer in read-only mode.
You are permitted to make file changes, run shell commands, and utilize your arsenal of tools as needed.
</system-reminder>
```

### Current mechanism

When Plan mode is active, OpenCode injects the `<system-reminder>` block (see [Raw system-reminder blocks](#raw-system-reminder-blocks) above for full text) on **every user message**. The block is always identical (26 lines, 228 words, ~300 tokens).

> **Source verification:** Verified against commit `650594e`. The injection code at `packages/opencode/src/session/reminders.ts:25-34` pushes `plan.txt` as a `synthetic: true` text part onto `userMessage.parts[]` (the last user message in the conversation array) on every turn when `agent.name === "plan"`. No deduplication guard, no frequency limit. Every user message in Plan mode receives the full block.

This is the same mechanism described within the agent prompt itself (`default.txt`, line 78):

> Tool results and user messages may include `<system-reminder>` tags. `<system-reminder>` tags contain useful information and reminders. They are NOT part of the user's provided input or the tool result.

The tag is **visible in the conversation stream**. It is not hidden metadata. The model is instructed to treat it as system instructions, not user input. (See [System-Reminder Overlays](../api-call-anatomy/README.md#system-reminder-overlays) in API Call Anatomy for the full mechanism.)

### Token cost

| Scenario | Plan turns | Tokens wasted | % of 128K | % of 200K |
|---|---|---|---|---|
| Quick chat | 3 | 900 | 0.7% | 0.45% |
| Medium session | 10 | 3,000 | 2.34% | 1.5% |
| Long debugging session | 25 | 7,500 | 5.86% | 3.75% |

Numbers alone are **not catastrophic**. Context windows are large enough (128K–200K) that the raw token cost is bearable.

> **Retry multiplier:** When the API fails (timeout/error), OpenCode
> automatically retries up to **6 times** with progressive backoff. Each
> retry re-sends the full conversation history (~11,700 input tokens),
> including the system prompt and the partial assistant response from the
> failed attempt. In a 10-turn Plan mode session, a single failure adds
> ~11,700 tokens on top of the 3,000 from the overlay — multiplying the
> real cost.

### Three real problems

#### 1. Habituation (the boy who cried wolf)

The reminder uses strong language: *"CRITICAL"*, *"STRICTLY FORBIDDEN"*, *"ZERO exceptions"*, *"overrides ALL other instructions"*. When this exact block appears 10+ times identically, the model learns to **tune it out**. The dramatic tone becomes noise. A system that shouts the same thing every turn ends up being ignored.

#### 2. Attention dilution

Each turn, the model must split its attention between:
- The user's actual message (goal, code, question)
- The system reminder (already known, already applied)

The reminder competes for the model's focus. Over many turns, this subtly degrades response quality. The model has to re-process known instructions before getting to the real input.

#### 3. No transition signal

Since the reminder is **identical every time**, the model has no way to detect a mode change without a **different** reminder being injected. The constant repetition trains the model to treat the block as background noise. When the mode actually changes (plan → build), the system must inject yet another block to break through that learned indifference.

### Design trade-off: uniform vs. varied overlay injection

OpenCode uses a **uniform** approach: the same full overlay block (~300 tokens,
26 lines) on every Plan mode turn. This is simple, predictable, and always
self-contained — the model never depends on previous context to understand the
restriction.

Some other harnesses use a **varied** approach with three overlay variants:

| Variant | When | Size |
|---------|------|------|
| **Full** | First entry to Plan mode | ~50 lines |
| **Compact** | Subsequent turns | ~4 lines (~90% less) |
| **Exit** | Single turn on exit | 1 line |

The full block establishes the rules. The compact block (on every following
turn) assumes the full block is still in recent context and uses fewer tokens.
The exit block signals the transition back.

Each design has trade-offs. Uniform is robust but repetitive. Varied is
token-efficient but risks the compact block becoming the sole reference if
context compaction removes the original full block.

#### Architectural limitation: harness reacts to tool calls, not intent

Regardless of overlay strategy, a deeper limitation applies to all
harness-injected mode switching: the mode change is triggered by the harness
intercepting `EnterPlanMode`/`ExitPlanMode` tool calls — it modifies the API
call for the next turn. It does not react to user intent directly. If the user
says "let's keep planning" after calling ExitPlanMode, the harness has already
removed the overlay. The model receives conflicting signals: user wants
planning, system instructions no longer restrict editing.

Control flags avoid this entirely because the flag is part of the user's
message, not a separate overlay toggled by tool calls. The model always sees
the current intent directly — no desync between what the user wants and what
the system enforces.

---

## Control flag limitations

1. **No system safety net.** Unlike OpenCode's Plan mode — which enforces read-only access at the harness level, blocking tool execution regardless of model behavior — control flags rely entirely on the model following the prompt instruction. If the model misreads, ignores, or hallucinates the flag, it may execute changes the user expected to be blocked. There is no second line of defense. For critical code, verify the model's response prefix (e.g., `[Analysis]`) before sending sensitive requests, and consider keeping Plan mode enabled for high-risk operations where absolute read-only enforcement is required.

2. **Prompt-dependent.** The model must be instructed about the flags in the custom prompt. Without that instruction, the flags have no effect.

3. **Single-user convention.** Flags are a convention between this specific user and model instance. They do not generalize to other users or contexts without the same prompt configuration.

4. **Learning curve.** Remembering seven suffixes (`¿¿`, `¡¡`, `{}`, `++`, `?¿`, `--`, `[]`) is more cognitive load than pressing Tab to enter Plan mode. Not all users want to learn a flag syntax.

5. **Flag buried in long messages.** If the user writes a very long message, the suffix at the end may receive less attention from the model. Consider placing flags at the beginning as `[LOCK] ...` instead of `... ¿¿` if this becomes an issue.

6. **Prefix fatigue.** In long sessions with many LOCK turns, `[Analysis]` at the start of every response becomes visual noise. Consider omitting the prefix after the first few turns if the model has already demonstrated compliance.

7. **No UI indicator.** OpenCode's Plan mode changes the prompt color to yellow with a "plan" badge. Control flags have no visual indicator. Everything depends on the suffix and the response prefix. A plugin that detects the flag and shows the mode in the UI would be a natural complement.

8. **Shared prompt overhead in reasoning phase.** When both Senior and Junior share the same `custom.md`, Pro processes sections it does not need — control flags, anti-closure rules, deflexion mitigations (~27% of the prompt). With `reasoningEffort: "high"`, this overhead is bounded (~4096 reasoning tokens). If Pro usage exceeds ~40% of interactions, consider splitting to `custom-senior.md` (stripped of Flash-only rules) + `custom-junior.md` for better reasoning efficiency. The trade-off is maintaining two prompts vs. running Pro with a leaner one. See [Battle Agent Prompt](../deepseek-battle-agent-prompt/README.md) for which rules apply to which model.
