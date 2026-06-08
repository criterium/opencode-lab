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

Also available in [Spanish](README.es.md) — all research documents have been translated.

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

### [DeepSeek V4 Flash Determinism](research/deepseek-v4-flash-determinism/README.md)

Three experiments measuring LLM determinism on analytical tasks:
single-prompt replicates (10×, σ=0.51), chained forks (3 branches,
22-33% agreement), and cross-model evaluation (4 models, 8 questions).
Reports a Global Determinism Index of 0.59 (poorly deterministic) and
shows that determinism depends on task granularity — convergence on
coarse ranking, divergence on fine scoring. Documents the majority
voting paradox (correlated bias makes consensus less reliable) and
6 mitigation strategies including multi-model orchestration.

### [DeepSeek V4 Flash vs Pro — Agent Prompt Battle](research/deepseek-battle-agent-prompt/README.md)

Compares DeepSeek V4 Flash (Junior) and DeepSeek V4 Pro (Senior)
as coding agents using the same custom prompt. Documents behavioral
profiles (Flash: broad sweep, closure impatience, deflection under
criticism; Pro: tunnel vision, security detection, multi-step tracking),
a decision tree for model selection, a Flash→Pro chaining strategy,
and 6 prompt rules derived from cross-model analysis.

### [DeepSeek V4 Flash vs Pro — Compaction](research/deepseek-battle-compaction/README.md)

Compares both models as context compaction models in OpenCode.
Demonstrates that Flash produces better results 4× faster and 13×
cheaper than Pro. Includes the "reasoning vs extraction" hypothesis,
model profiles (tunnel effect investigator vs wide-spectrum explorer),
escape mechanisms of both models, prompt tips per model, and the finding
that identity preservation trumps evidence in both.

### [Memory System for Coding Assistants](research/memory-system/README.md)

A manual, flat-file memory system for AI coding assistants. Uses `>>`/`<<`
operators to save and load context on demand — zero tokens until invoked.
Compares three approaches: OpenCode's AGENTS.md, an autonomous model-driven
memory, and this human-in-control alternative. Documents design principles,
workflow, operators, scopes, and a comparative analysis across 17 dimensions.

### [OpenCode Zen Free MiMo Flash — Comparative Analysis](research/opencode-zen-free-mimo-flash/README.md)

Compares MiMo V2.5 Free and DeepSeek V4 Flash Free across 7 prompt-based
tasks evaluating instruction adherence, code generation accuracy, output
structure compliance, and behavioral profiles. Reports Flash wins 5/7
questions with 81.3% `custom.md` compliance vs 37.5% for MiMo. Based on
live sessions with real OpenCode context assembly, not static benchmarks.

### [OpenCode Zen Free Models — Evaluation](research/opencod-zen-free-models/README.md)

Evaluates 4 free models (DeepSeek V4 Flash Free, MiMo V2.5 Free,
MiniMax M3 Free, Nemotron 3 Super Free) as analytical evaluators
on 8 sequential questions over 343 KB of technical documents.
Scores each model on per-question quality, global coherence, final
report, operational fluency, and theoretical cost. DeepSeek leads
(9.14) with zero errors and stable σ=0.35; MiMo is fastest (213s)
but has format errors; MiniMax is 3.7× slower; Nemotron fails
critically (4.29). Includes cross-validation with 10 replicates.

### [Reasoning Effort in DeepSeek V4 and OpenCode](research/opencode-deepseek-v4-reasoning-effort/README.md)

Documents the flow of the `reasoning_effort` parameter from the DeepSeek
V4 API through its integration with OpenCode. Reveals that DeepSeek
detects complex agents through multifactorial signals (tools +
`x-session-affinity` header), forcing `"max"` reasoning effort regardless
of the configured value on Go and Zen channels. Includes the channel map,
practical guide, empirical verification procedure, and drop-thinking analysis.

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
