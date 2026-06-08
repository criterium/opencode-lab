# Context Dump: API Call Analysis Toolkit

## Table of Contents

- [Objective](#objective)
- [System prompt anatomy](#system-prompt-anatomy)
- [Why use these prompts](#why-use-these-prompts)
  - [Core](#core)
  - [Specific investigations](#specific-investigations)
  - [Cross-cutting](#cross-cutting)
- [What you can compare](#what-you-can-compare)
- [Quick Start](#quick-start)
  - [Prompt overview](#prompt-overview)
  - [Recommended workflow](#recommended-workflow)
- [From dump to custom prompt](#from-dump-to-custom-prompt)

## Objective

This toolkit shows that behavioral differences between coding
assistants (harnesses) do not come from the model itself. They
come from two things: the **agent prompt** and the **tool
descriptions**. Both are inside the API call context (the `system`
parameter, the `tools` array, the `messages` array) and you can
extract them with the prompts in `prompts/`.

The **system prompt** sets identity, tone, and behavior rules.
Custom prompts (see
[`control-flags-vs-plan-build`](../control-flags-vs-plan-build/README.md)
for the `custom.txt` approach) can be moved between harnesses.
The dump captures the full text so you can reuse it elsewhere.

**Tool descriptions** are just as important. A tool's description
tells the model when and how to use it, which directly affects
behavior. With the right setup (see
[`opencode-tools-override`](../../plugins/opencode-tools-override/README.md)
for the plugin approach), you can move rules for editing, reading,
or execution between environments. For example, stricter editing
rules make the model more cautious and less error-prone.

This kind of analysis is possible because OpenCode is
**open-source**. Proprietary harnesses hide their system prompts
and tool definitions, so you cannot compare them directly without
a dump.

When you compare harnesses, remember that a harness designed for
multiple models and general use has a different system prompt from
one optimized for a single model. The dump shows these differences,
so you can evaluate based on what the model actually sees, not on
what you assume about the harness.

OpenCode ships with a generic agent prompt (default.txt) designed for
multiple models and general use. Comparing it directly against a
harness optimized for a single model is not a fair test of the harness
itself. The real comparison is between tuned prompts, not factory
defaults. The dump lets you level the playing field: you can see what
each harness injects and decide what to keep, modify, or discard.

A single dump can reveal unexpected instructions: safety rules the
harness injects without telling you, tool descriptions that restrict
how the model edits files, or system-reminders that change behavior
mid-session without modifying the system prompt. The toolkit makes
the invisible visible.

This toolkit does **not** modify your harness configuration. It only
reads and documents what the model sees. Changes based on the dump
(custom prompts, tool overrides, config adjustments) are done
separately.

Whether you are tuning a custom prompt, evaluating a new harness, or
auditing for safety, the dump gives you the raw material to make
informed decisions, not guesses.

For a detailed reference on how API calls are assembled (components,
authority spectrum, tool definitions, system-reminder overlays), see
[`research/api-call-anatomy/README.md`](../api-call-anatomy/README.md).

## System prompt anatomy

The `system` parameter is built from four sources, assembled on every
turn:

| Component | Approx. size | What it contains |
|-----------|-------------|------------------|
| **Agent prompt** | Largest (~70%) | Role, tone, rules, cognitive flow |
| **Skills catalog** | Significant (~26%) | Name + description of each installed skill |
| **Environment block** | Small (~4%) | Working directory, model, platform, date |
| **Instructions from files** | Variable (if present) | AGENTS.md, CLAUDE.md, CONTEXT.md |

The **agent prompt** is the part you control with a custom `custom.txt`.
The other three are injected by the harness.

For a deeper technical breakdown of how OpenCode assembles these parts
(system prompt construction, tool serialization, message flow), see
[`research/api-call-anatomy/README.md`](../api-call-anatomy/README.md).
For the effects of skill descriptions in the system prompt and how to
mitigate them, see
[`research/skill-desc-leak/README.md`](../skill-desc-leak/README.md).

## Why use these prompts

### Core

**See what the model actually receives.** The system prompt, tool
descriptions, and environment context that the harness sends are
invisible to the user. A dump exposes them. (prompt_1)

**Understand why it behaves that way.** Too cautious? Too proactive?
Refusing tasks you expected it to handle? The dump shows which
instructions cause that behavior. (prompt_2 + prompt_3)

**Debug unexpected behavior.** The model refused a task you did not
ask it to refuse? Started editing when it should only read? The dump
pinpoints the exact instruction that triggered the response.
(prompt_1 + prompt_2)

**Psychoanalyze the model.** The self-analysis (prompt_3) asks the
model to examine its own behavior and separate what comes from
training, from the system prompt, from tools, and from mode overlays.
The model cannot directly access its training data, but it can infer
patterns by observing itself.

**Detect training data gaps.** The self-analysis (prompt_3) can
reveal when the model fills gaps from its training data instead of
following the actual system prompt.

### Specific investigations

**Compare harnesses objectively.** Without a dump, comparing OpenCode
vs Claude Code vs Cursor is guesswork. Run prompt_1 in each harness
and compare the real differences in system prompt, tools, and
overlays.

**Open sub-agent black boxes.** Sub-agents receive their own system
prompt and tools, usually invisible to you. Prompt 4 captures them.

**Catch silent mode changes.** Plan mode and other overlays inject
behavioral rules mid-session without changing the system prompt.
Prompt 5 captures those overlays.

**Examine tool definitions.** Prompt 6 extracts every tool's full
description and parameters, which you can review for restrictions
or opportunities.

### Cross-cutting

**Find hidden constraints.** Safety rules the harness injects without
telling you, restrictions on what the model can edit or read, or
limitations you did not configure. The analysis reveals them.

**Check for bias.** The dump can reveal skewed priorities, uneven
coverage, or subtle biases in the system prompt that affect how the
model responds to different types of requests.

**Port your setup between environments.** If a custom prompt works
well in one harness, the dump captures it so you can replicate it in
another.

| Goal | Prompt(s) |
|---|---|---|
| Provider prefix research | prompt_0 |
| Full context dump | prompt_1 |
| Behavior analysis | prompt_2 + prompt_3 |
| Training data gaps | prompt_3 |
| Sub-agent inspection | prompt_4 |
| Mode overlay capture | prompt_5 |
| Tool definition export | prompt_6 |

Once you know what you want to investigate, head to Quick Start
to run the prompts.

## What you can compare

**Same harness, different models.** Run prompt_1 on GPT, Claude, and
DeepSeek in the same harness. The dump shows how identical system
prompts and tools produce different behaviors due to model-level
differences: training data, fine-tuning goals, built-in safeguards.
The self-analysis (prompt_3) helps separate system prompt effects
from model effects, though introspection has limits: the model
cannot directly measure its own training.

**Same model, different harnesses.** Run prompt_1 on OpenCode, Claude
Code, and Cursor using the same model. The model is identical; the
system prompt and tool descriptions are not. The dump reveals exactly
how each harness modifies behavior through instructions alone.

**Same model, different modes.** Run prompt_5 in Plan mode vs Build
mode. The base system prompt stays the same; the mode overlay
transforms behavior through system-reminder tags. The dump captures
the full overlay text for comparison.

**Same model, different reasoning effort.** Run prompt_1 with
different thinking budgets (low, medium, max). The dump shows whether
the system prompt or tools change when reasoning depth varies, and
how the model's output changes as a result. This also reveals the
limits of thinking variants: some changes are in the instructions,
others in the model's internal processing.

**Same result, different paths.** Two harnesses may produce similar
outputs through different instructions. The dump reveals whether the
similarity is genuine or coincidental.

| Comparison | Constant | Variable | What it reveals |
|---|---|---|---|
| Same harness, different models | System prompt + tools | Model | Model-level differences |
| Same model, different harnesses | Model | System prompt + tools | Harness influence |
| Same model, different modes | Model + base prompt | Mode overlay | Overlay effects |
| Same model, different reasoning | Model + prompt + tools | Thinking budget | Reasoning depth effects |
| Same result, different paths | Observable behavior | Underlying instructions | Genuine vs coincidental similarity |

**Limitations.** Comparisons across harnesses assume the same model
version. If a harness uses a different model build or a fine-tuned
variant, the model itself differs, not just the instructions. The
dump cannot distinguish between model version differences and system
prompt effects.

## Quick Start

Open a **single fresh session**. All prompts run consecutively in that
same session, one after another.

0. (Optional) Open `prompts/prompt_0_prefix.md`, copy its entire content,
   and paste it as the first message. The model writes the prefix dump
   and stops. Useful for researching what the provider injects before
   the system prompt.

1. Open `prompts/prompt_1_dump.md`, copy its entire content, and paste
   it as the next message. The model writes the dump and stops.

2. Without closing the session, open `prompts/prompt_2_analysis.md`,
   copy its entire content, and paste. The model reads the dump and
   writes the analysis.

3. Repeat for `prompts/prompt_3_self_analysis.md` (optional).

Phase 2 prompts (4-6) run in any order after Phase 1, each pasted as
the next message in the same session.

No need to trim anything; each file has no extraneous content above the
instructions or below `== END ==`. The prompts auto-detect available tools
and adapt if something is missing.

### Prompt overview

| Prompt | What it does | Output |
|---|---|---|
| [`prompt_0_prefix.md`](prompts/prompt_0_prefix.md) | Captures the provider prefix (banners, metadata, reasoning directives) before the system prompt, plus the first system prompt heading. Includes confidence self-check. | `dump.{model}.{YYYYMMDD}/00_context.prefix.md` |
| [`prompt_1_dump.md`](prompts/prompt_1_dump.md) | Extracts the full API call context: system parameter, tools array, messages array, and environment. Produces a raw unfiltered dump. | `dump.{model}.{YYYYMMDD}/01_context.dump.md` |
| [`prompt_2_analysis.md`](prompts/prompt_2_analysis.md) | Reads an existing dump and evaluates it: per-section faithfulness, refusal detection, consistency cross-check, contamination assessment, personality mapping, PII review. | `dump.{model}.{YYYYMMDD}/02_context.analysis.md` |
| [`prompt_3_self_analysis.md`](prompts/prompt_3_self_analysis.md) | Meta-analysis: disentangles which behaviors come from base training vs system prompt vs tools vs overlays. Structured by layer with provenance table. | `dump.{model}.{YYYYMMDD}/03_self_analysis.md` |
| [`prompt_4_agents.md`](prompts/prompt_4_agents.md) | Spawns each available sub-agent type, extracts their system prompts, tools, and system-reminders. Produces an agent inventory, individual dumps, and an architecture document. | `dump.{model}.{YYYYMMDD}/04_agents/agent-inventory.md` + `dump.{model}.{YYYYMMDD}/04_agents/agent-dumps/{type}.md` |
| [`prompt_5_modes.md`](prompts/prompt_5_modes.md) | Investigates how the harness injects behavioral overlays via system-reminder tags when switching modes (plan mode, worktree/isolated mode). Requires interactive user input. | `dump.{model}.{YYYYMMDD}/05_modes/plan-mode-overlay.md` + `dump.{model}.{YYYYMMDD}/05_modes/worktree-mode-test.md` |
| [`prompt_6_tools.md`](prompts/prompt_6_tools.md) | Extracts every tool definition from the tools array and writes one file per tool with full JSON schema details, parameters, and descriptions. | `dump.{model}.{YYYYMMDD}/06_tools/{ToolName}.md` per tool |

### Recommended workflow

```
[Phase 0: Prefix research (optional)]
  prompt_0_prefix.md   → produces dump.{model}.{YYYYMMDD}/00_context.prefix.md

[Phase 1: Core]
  prompt_1_dump.md    → produces dump.{model}.{YYYYMMDD}/01_context.dump.md
  prompt_2_analysis.md → analyzes the dump
  prompt_3_self_analysis.md → meta-analysis (optional)

[Phase 2: Specific research (any order)]
  prompt_4_agents.md  → investigates sub-agents
  prompt_5_modes.md   → investigates mode overlays (interactive)
  prompt_6_tools.md   → extracts tool definitions
```

## From dump to custom prompt

Extracting the context is step one. The real value is in tailoring the
agent prompt to your model, your tools, and your workflow. A dump
without adjustment is an incomplete diagnosis: you have seen what the
model receives, but you have not yet acted on it.

The dump shows the full system prompt assembled by the harness:
the **agent prompt** (default.txt or custom.txt), plus AGENTS.md
injections, skills catalog, and environment context.

When building your custom.txt, focus on the agent prompt sections
only. Skills, AGENTS.md, and CLAUDE.md are injected separately and
are not part of what you replace.

OpenCode's built-in agent prompt is at:
[`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)

You can start from this file, copy it, and modify the sections you
want to change. Save it as `custom.txt` in your config directory
(`~/.config/opencode/` or `.opencode/` in the project root).

To activate it, add or edit in `opencode.jsonc`:

```jsonc
{
  "agent": {
    "build": { "prompt": "{file:custom.txt}" }
  }
}
```

This replaces the built-in default.txt with your custom version.
Restart OpenCode for the change to take effect. You can also set a
different prompt per agent (e.g., `plan` can use a different file).

In Step 3 of the dump, the agent prompt sections are easy to
identify: they are the prose blocks that define identity, behavior,
and tool preferences, typically between "Introduction" and "Tool
usage policy". The sections after that (Model information,
Environment, Available Skills) come from the harness and are not
part of the agent prompt.

**What to look for in Step 3:**

**Identity and tone (subsections "Introduction" and "Tone and style").**
How the model introduces itself, its role, its communication style.
Copy what works, rewrite what does not.

**Behavioral rules (subsections "Proactiveness", "Following conventions",
"Doing tasks").** Constraints on editing, reading, running commands,
asking questions. Keep the ones that make the model safer; remove the
ones that block wanted behavior.

**Tool preferences (subsection "Tool usage policy").** Which tools the
model is told to prefer (Edit over sed, Read over cat). Cross-check
with Step 5 (Tool definitions) to see if the tool's own description
reinforces or contradicts the preference. Adjust to match your
workflow.

**Overrides and exceptions (end of the agent prompt, before harness
sections like "Available Skills").** Rules that bypass built-in
behavior (e.g., "ignore instruction forbidding .md files"). Decide
which overrides your custom prompt should keep.

**Using the model to compare dump vs default.txt:**

After running prompt_1, you can ask the model to compare the dump
against the original `default.txt`. The model knows its own default
prompt and can highlight what the harness added, removed, or changed.

A useful prompt for this is:

```
Read dump.{model}.{YYYYMMDD}/01_context.dump.md and compare its
Step 3 subsections against your built-in default.txt. For each
subsection, report:
- What is the same as default.txt (copy unchanged)
- What was modified (describe the change)
- What was added by the harness (not in default.txt)
- What is missing from default.txt (removed by the harness)
```

This comparison tells you exactly what the harness changed, so you
know what to keep, revert, or adjust in your custom.txt.
