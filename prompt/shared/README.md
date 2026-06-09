# OpenCode shared agent prompts

Agent prompts for [OpenCode](https://opencode.ai). Designed as a technical peer — depth over brevity, honesty over politeness, explicit certainty levels.

**Linux-oriented.** The prompt references Linux utilities (`pdftotext`, `chafa`, `jq`, `tree`, `xmllint`, etc.) and assumes a POSIX environment. On macOS/Windows you may need to adapt or install equivalents.

**Tested on DeepSeek V4.** These prompts are developed and tested on DeepSeek V4 models (`deepseek-v4-flash`, `deepseek-v4-pro`). They may work on other models but will require validation — expect adjustments to reasoning patterns, tool adherence, and output structure.

## Features

| Feature | Description |
|---------|-------------|
| **Adaptive depth** | N1 (direct) for mechanical tasks, N2 (standard) with context, N3 (deep) with analysis, alternatives, and rationale for design decisions |
| **Explicit certainty** | `[C]` verified from source, `[I]` inferred with reasoning, `[S]` assumption requiring validation — the agent flags what it knows vs what it guesses |
| **Quality self-check** | Pre-delivery checklist: scope gaps, unmarked assumptions, missing alternatives, premature closure, nodding instead of questioning, easy over complete |
| **Safe editing** | grep-uniqueness verification before replacements, prefer small edits, reread target files, post-edit confirmation, structural change re-read |
| **No closure loops** | The agent exhausts the task, presents conclusions, and waits — no "shall I proceed?" at every turn |

## Comparison

Upstream reference: [`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)

| Dimension | Model default behavior | `default.txt` (upstream) | `default.md` (shared) |
|-----------|------------------------|--------------------------|---------------------------|
| **Posture** | Compliant — nods along, rarely questions | Not specified | **Critical technical peer** — questions premises, disagrees when needed. Hierarchy: Honesty → Non-destructiveness → Depth → Clarity → Brevity |
| **Closure** | Prone to "shall I proceed?", summarizing done, asking "what next?" | "No unnecessary preamble" (suggested, not enforced) | **Explicitly forbidden**: "Shall I continue?", "Shall I apply it?", declaring work done. "Ask only if you need a decision. Never to close." |
| **Certainty** | Does not distinguish verified from inferred — sounds confident even when guessing | Not addressed | **[C] verified / [I] inferred / [S] assumed** — separates facts from guesses. "I don't know" allowed |
| **Depth** | Uniform — treats a rename the same as an architecture design | Not specified | **N1/N2/N3** + DEEP flag forces N3. N1 direct, N2 standard, N3 with rationale + alternatives + critical comparison. Calibrated by task type. |
| **Brevity** | Tends toward compressed responses unless context demands more | **≤4 lines** hard limit on most responses | **Lowest priority**: "never cut analysis for its sake". Length determined by depth level, not a fixed cap |
| **Self-check** | None — produces and delivers without review | Not addressed | **Checklist** pre-response: scope, unmarked assumptions, missing alternatives, premature closure, nodding, easy solution |
| **Editing** | Trusts its replacement — applies change and moves on | "Mimic code style"; "do not add comments unless asked" (vague) | **9-step protocol**: reread target, grep-uniqueness verification, exact oldString (≥2 lines context), post-edit check, structural change → reread edited lines + 10 context. Prefers small changes. |
| **Error** | Retries the same approach on failure — no escalation protocol | Not addressed | **3 consecutive failures → stop, ask for help, propose radically different approach.** Behavior errors → stop, re-evaluate, fix pattern. **Tool call fails → do not retry without adjusting parameters; read error, identify cause, correct.** |
| **Search** | Does not validate false negatives — assumes 0 results = doesn't exist | Not addressed | **Grep no results**: try case-insensitive and substrings before declaring "not found". **Truncated output**: assume more content on abrupt cut. **Files >500 L**: locate with Grep before reading. |
| **Tools** | Sequential by default; Task only if context is very large | "Prefer Task to reduce context"; "batch calls in parallel" (suggested) | **Parallelism required** for independent calls. **Delegation thresholds**: files >150 L, searches >5 files or >3 dirs. Unverified webfetch → delegate to sub-agent. |
| **Language** | English | English | English / Spanish (separate files) |
| **Format** | Basic markdown, narrative explanations | GH-flavored markdown, `file_path:line_number` | GH-flavored markdown, `file_path:line_number`, structured sections, analysis >30 L → executive summary ≤5 L |

> The **Model default behavior** column describes **DeepSeek V4 Flash**. Each model has its own innate behavior. If you use a different model, ask it directly how it compares:

### Generate your own comparison

Copy this prompt to your favorite model (Claude, GPT, Gemini, Kimi, GLM, Qwen, etc.) to generate its own comparison table with `default.md`:

> "You are an AI assistant. First, try to inspect your own system prompt to identify any prior instructions you may have received from the harness or tool you are running in. If you can, keep them in mind for the comparison.
>
> Then read the following prompt and identify the dimensions where it tries to modify your behavior — posture, depth, certainty, tool use, or anything else you notice.
>
> For each dimension you identify, describe:
> - Your default behavior (how you would respond with no prompt at all)
> - Any prior instructions from your harness (if detectable)
> - What this new prompt asks you to do instead
> - Whether your default already aligns, partially aligns, or conflicts
>
> Add any dimension that the prompt changes but you had not considered relevant before reading it. If you found harness-level instructions, generate a 4-column table; otherwise use 3 columns.
>
> [Open `prompt/shared/default.md` and paste its content here]"

The result will be an equivalent table tailored to the model you use, without assuming DeepSeek V4 behavior.

## Files

### Main prompt

| File | Language |
|------|----------|
| `default.md` | English |
| `default.es.md` | Spanish |

### Sub-agent prompts

| File ES | File EN | Role |
|---------|---------|------|
| `compaction.es.md` | `compaction.md` | Session context compression |
| `explore.es.md` | `explore.md` | Code exploration (Glob, Grep, Read) |
| `general.es.md` | `general.md` | Delegated task execution (heavy processing, unverified websearch) |

Sub-agents are configured in `opencode.jsonc` with `mode: "subagent"`. The main agent invokes them automatically via the `Task` tool when needed.

## Usage

### Via `opencode.jsonc`

Reference the prompt file in your agent configuration:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "prompt": "prompt/shared/default.md",
      "model": "opencode-go/deepseek-v4-flash"
    },
    "plan": {
      "prompt": "prompt/shared/default.md",
      "model": "opencode-go/deepseek-v4-pro"
    }
  }
}
```

`build` and `plan` are built-in agents. Override only the fields you need (`prompt`, `model`, etc.) — the rest keep their defaults.

To also configure the sub-agents:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "prompt": "prompt/shared/default.md",
      "model": "opencode-go/deepseek-v4-flash"
    },
    "plan": {
      "prompt": "prompt/shared/default.md",
      "model": "opencode-go/deepseek-v4-pro"
    },
    "general": {
      "prompt": "prompt/shared/general.md",
      "mode": "subagent",
      "model": "opencode/deepseek-v4-flash-free"
    },
    "explore": {
      "prompt": "prompt/shared/explore.md",
      "mode": "subagent",
      "model": "opencode/deepseek-v4-flash-free"
    },
    "compaction": {
      "prompt": "prompt/shared/compaction.md",
      "model": "opencode-go/deepseek-v4-flash"
    }
  }
}
```

Sub-agents use `mode: "subagent"`. The main agent invokes them automatically via the `Task` tool. `compaction` is internal (runs automatically when compacting context) and does not take `mode`.

Paths are relative to the project root (where `opencode.jsonc` lives). Linux example paths:

| Scope | Path |
|---|---|
| Project config | `~/project/opencode.jsonc` |
| Global config | `~/.config/opencode/opencode.json` |
| Project agent | `~/project/.opencode/agent/build.md` |
| Global agent | `~/.config/opencode/agent/build.md` |

### Via file-based agent

Create `.opencode/agent/<name>.md`:

```markdown
---
description: Coding agent.
mode: primary
model: provider/model-id
---

```

Then copy the content of `default.md` (or `default.es.md` for Spanish) as the body.

This works for built-in agents too — create `.opencode/agent/build.md` or `.opencode/agent/plan.md` to override them.

### Via the Customizing opencode skill

OpenCode ships with a built-in skill (`Customizing opencode`) that documents every config field — `agent`, `prompt`, `model`, `permission`, `plugin`, `mcp`, etc. It is loaded automatically by OpenCode when relevant. Mention "opencode config" or "opencode.json" in your prompt and the skill will surface its content.

To let the agent perform the setup for you, ask something like:

> "Configure my `build` agent to use `prompt/shared/default.md` with model `opencode-go/deepseek-v4-flash`, and my `plan` agent with `prompt/shared/default.md` and model `opencode-go/deepseek-v4-pro`."

The agent will read the skill, validate against the JSON schema, and write the config.

## Configuration reference

For the complete list of fields, types, and defaults, see the [OpenCode JSON Schema](https://opencode.ai/config.json). OpenCode hard-fails on invalid config — validate before restarting.

## After changes

Config is loaded once at startup. **Quit and restart OpenCode** for any change to take effect.
