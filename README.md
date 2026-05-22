# OpenCode Lab

An unofficial lab for the [OpenCode](https://github.com/sst/opencode) AI
agent: recipes, benchmarks, experiments, and tricks for understanding and
controlling how it behaves.

The key advantage: OpenCode is a great open-source project. Unlike
proprietary coding assistants, where the system prompt and context
assembly are a black box, OpenCode lets you inspect everything.

You can see exactly how system prompts are built, how skill
descriptions leak into context, how tool descriptions steer the model,
and how AGENTS.md injects instructions on every turn. That transparency
gives you the flexibility to analyze, modify, and control behavior in
ways closed tools do not allow.

This repo documents those mechanisms and gives you prompts, plugins,
and reference material to take advantage of that flexibility.

Not affiliated with the OpenCode project.

---

## Research

### [AGENTS.md Danger Analysis](research/agents_md-danger/README.md)

Examines the risks of automatic AGENTS.md loading through three
independent injection paths (global, project root, subdirectory).
Argues that habits formed in tools with small context windows
carry over to OpenCode where they cause bloat, anxiety, and
latency. Documents the per-read subdirectory injection mechanism
that no configuration flag can block.

### [API Call Anatomy](research/api-call-anatomy/README.md)

A reference document that explains the three-part API call structure
(`system` + `messages` + `tools`) and how OpenCode assembles each part.
Covers the system prompt assembly pipeline, custom prompt resolution,
AGENTS.md injection paths, system-reminder overlays, tool definition
structure, and the instruction authority spectrum. 764 lines, the
foundation for all other research in this repo.

### [Context Dump Toolkit](research/context-dump/README.md)

Six operational prompts that extract and analyze the full API call
context from a running OpenCode session. Prompt 1 dumps the system,
tools, and messages fields. Prompts 2-3 analyze the dump for
faithfulness, refusal patterns, and contamination from training data.
Prompts 4-6 extract sub-agent system prompts, mode-switching overlays,
and tool definitions. Includes a quick-start workflow and a guide to
moving extracted prompts between harnesses.

### [Control Flags vs Plan/Build](research/control-flags-vs-plan-build/README.md)

Replaces OpenCode's binary Plan/Build mode switch with seven
user-level control flags that direct the model's cognitive mode
without harness modifications. Each flag (LOCK, IDEAS, PLAN,
EXPLAIN, REQUIRE, SUMMARY, EXIT) tells the model what kind of
thinking to perform. Includes a ready-to-use prompt template that
can be appended to any custom prompt file and is portable across
harnesses.

### [Skill Description Leak](research/skill-desc-leak/README.md)

Investigates how skill descriptions automatically enter the system
prompt on every turn through the `available_skills` XML block
(approximately 26% of the system prompt). Includes a proof of concept
with a persona-injection skill (Grillo), evidence of real-world
degradation when skills accumulate, and a technology bias example.
Documents two mitigation approaches: a protocol-only approach (Option A)
and a plugin-based loader with on-demand loading (Option B, recommended).

---

## Plugins

### [opencode-tools-override](plugins/opencode-tools-override/README.md)

A plugin that overrides OpenCode tool descriptions using plain
`.txt` files. Tool descriptions carry higher authority than system
prompt instructions, making this the ideal place for behavioral
rules, domain-specific constraints, and custom workflows. Also
saves tokens by shortening verbose built-in descriptions.

Used in the [Skill Description Leak](research/skill-desc-leak/README.md)
research as one of two mitigation options (plugin-based skill loading).
Can also be combined with the [Context Dump](research/context-dump/README.md)
toolkit: override tool descriptions before dumping to compare how
different descriptions affect the model's tool-use behavior.

---

*Antonio Muñoz*
