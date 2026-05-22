# API Call Anatomy: How OpenCode Talks to Language Models

A reference document explaining the structure of API calls from OpenCode to
language models.

**Contents**

  - [1. The Three-Part API Call](#1-the-three-part-api-call)
    - [The `system` Parameter](#the-system-parameter)
    - [The `messages` Array](#the-messages-array)
    - [The `tools` Array](#the-tools-array)
    - [Additional Parameters](#additional-parameters)
    - [Full Request Example](#full-request-example)
  - [2. System Prompt Assembly](#2-system-prompt-assembly)
    - [Components](#components)
    - [Custom Prompt Resolution](#custom-prompt-resolution)
    - [Instructions from AGENTS.md](#instructions-from-agentsmd-three-levels-two-injection-mechanisms)
    - [Skill Descriptions in the System Prompt](#skill-descriptions-in-the-system-prompt)
  - [3. Agent Configuration](#3-agent-configuration)
    - [Overriding Built-in Sub-agent Prompts](#overriding-built-in-sub-agent-prompts)
  - [4. Messages Array in Depth](#4-messages-array-in-depth)
    - [Message Roles](#message-roles)
    - [System-Reminder Overlays](#system-reminder-overlays)
  - [5. Tool Definitions](#5-tool-definitions)
    - [Structure](#structure)
    - [Registration and Filtering](#registration-and-filtering)
    - [Tool Description Overrides](#tool-description-overrides)
  - [6. Instruction Authority & Strategy](#6-instruction-authority-strategy)
    - [Authority Spectrum](#authority-spectrum)
    - [Comparison](#comparison)
    - [Practical Guidelines](#practical-guidelines)
    - [Token Budget Strategy](#token-budget-strategy)

---

## 1. The Three-Part API Call

Every OpenCode API call to a language model has three structural components:

| Component | Role | Location in HTTP |
|-----------|------|------------------|
| **System** | Instructions, identity, environment context, skill catalog | Root field `system` (string) |
| **Messages** | Conversation history | Root field `messages` (array) |
| **Tools** | Function definitions the model can call | Root field `tools` (array) |

This structure is invariant across providers and harnesses. It is the only
gateway into the model. Any behavioral influence: instructions, constraints,
persona: must pass through one of these three channels.

Additionally, model-specific parameters are sent as root fields:

| Parameter | Example | Purpose |
|-----------|---------|---------|
| `model` | `"deepseek/deepseek-v4-pro"` | Identifies the target model |
| `max_tokens` | `8192` | Response length limit |
| `stream` | `true` | Enable streaming response |
| `thinking` | `{"type": "enabled"}` | Enable thinking mode (Anthropic API) |
| `temperature` | `0.7` | Sampling temperature (not sent when thinking is enabled) |
| `top_p` | `0.9` | Nucleus sampling (not sent when thinking is enabled) |

### The `system` Parameter

The `system` parameter is a plain string containing the system prompt. It is
assembled from multiple components (see [System Prompt Assembly](#2-system-prompt-assembly))
and sent as a single UTF-8 string.

In the SDK layer, segments are mapped to `{role: "system"}` message objects,
then the Vercel AI SDK (`@ai-sdk/*`) converts them to a root `system` field
for Anthropic-compatible APIs, or keeps them as system messages for
OpenAI-compatible APIs.

### The `messages` Array

The messages array contains the full conversation history. The format
varies by provider: OpenCode's SDK layer normalizes internally and
converts to the target provider's wire format:

**OpenAI-style** (used by OpenAI, most compatible models, and the
internal SDK representation):

```json
[
  {"role": "user",      "content": "..."},
  {"role": "assistant", "content": "..."},
  {"role": "tool",      "content": "...", "tool_use_id": "..."},
  {"role": "user",      "content": "..."}
]
```

**Anthropic-style** (used by Anthropic API: tool
calls use `type: "tool_use"` in assistant, tool results use
`role: "user"` with `type: "tool_result"`):

```json
[
  {"role": "user",      "content": [{"type": "text", "text": "User message"}]},
  {"role": "assistant", "content": [
    {"type": "text", "text": "I'll look that up."},
    {"type": "tool_use", "id": "tu_123", "name": "glob", "input": {"pattern": "*.txt"}}
  ]},
  {"role": "user",      "content": [{"type": "tool_result", "tool_use_id": "tu_123", "content": "file.txt"}]},
  {"role": "user",      "content": [{"type": "text", "text": "Next question"}]}
]
```

The SDK converts between these formats transparently. The rest of this
document refers to the OpenAI-style for simplicity.

> **Important**: `role: "tool"` messages (OpenAI-style) or `type: "tool_result"`
> (Anthropic-style) contain **tool results**: the output returned after a tool
> call executes. These are distinct from the **`tools` array** (root field),
> which contains **tool definitions**: the function schemas the model uses to
> decide which tool to call. Definitions and results are separate data that
> happen to share a name; they appear in different parts of the API call.

Each turn appends: user message → assistant response (text + tool calls) →
tool results. The full history is sent on every request.

Messages may also contain `<system-reminder>` tags: synthetic text parts
injected by mode-switching logic (see [System-Reminder Overlays](#system-reminder-overlays)).

### The `tools` Array

Tools are serialized as:

```json
[
  {
    "name": "glob",
    "description": "Find files matching a glob pattern...",
    "input_schema": {
      "type": "object",
      "properties": {
        "pattern": {"type": "string"},
        ...
      },
      "required": ["pattern"]
    }
  }
]
```

The model uses these definitions to decide which tool to call and with what
arguments. Tools are registered, filtered by model/provider capability, and
serialized for each request.

### Additional Parameters

Beyond the three structural components, each request includes parameters
that control inference behavior:

| Parameter | Purpose | Notes |
|-----------|---------|-------|
| `max_tokens` | Maximum response tokens | Hard limit |
| `stream` | Enable streaming response | `true` / `false` |
| `thinking` / `extended_thinking` | Enable reasoning mode | Provider-specific (see below) |
| `temperature` | Sampling temperature | Disabled when thinking is active (see below) |
| `top_p` | Nucleus sampling | Disabled when thinking is active (see below) |
| `stop` | Stop sequences | Rarely used |

These values are merged from the agent configuration, provider defaults,
and OpenCode's internal mapping (reasoningEffort → thinking parameters).

#### Thinking / Reasoning Mode

When thinking mode is enabled (default for supported models):

- `temperature` and `top_p` are **not sent** in the API request
- DeepSeek Anthropic API: `thinking: {type: "enabled"}` or
  `thinking: {type: "enabled", budget_tokens: 4096}`
- The model produces a thinking block followed by the visible response
- `reasoningEffort` from OpenCode config is mapped to provider-specific
  thinking parameters

Configuration mapping for `reasoningEffort`:

| OpenCode value | DeepSeek Anthropic API |
|----------------|----------------------|
| `"low"` | `thinking: {type: "enabled", budget_tokens: 1024}` |
| `"medium"` | `thinking: {type: "enabled", budget_tokens: 2048}` |
| `"high"` / `"max"` | `thinking: {type: "enabled", budget_tokens: 4096}` or unlimited |

#### Temperature and Top-P

- Only apply when thinking mode is **disabled**
- When thinking is enabled, the model ignores temperature/top_p
- Default values: temperature `0.7`, top_p `0.9` (varies by provider)

#### Provider Differences

| Aspect | Anthropic Messages API | OpenAI API | Google API |
|--------|---------------|------------|------------|
| System prompt | Root `system` field | Array of `{role: "system"}` messages | `system_instruction` field |
| Thinking | `thinking: {type: "enabled"}` | `reasoning_effort` | N/A |
| Tool format | `input_schema` | `parameters` | `parameters` |
| Supported models | Claude | GPT-4, GPT-4o, o1, o3 | Gemini |

OpenCode normalizes these differences through the provider layer
so the rest of the system uses a consistent interface.

---

### Full Request Example

The same session produces different wire formats depending on the
provider. OpenCode uses the **OpenAI-compatible** format by default for
most providers (including DeepSeek and OpenCode's free tier); the
Anthropic Messages API format is used for Anthropic provider models.

**OpenAI-compatible API** (default for most providers, including DeepSeek):

```
POST https://api.deepseek.com/v1/chat/completions
```

```json
{
  "model": "deepseek-v4-pro",

  "messages": [
    {"role": "system", "content": "Context and environment\n...\n\nIdentity and style\n..."},
    {"role": "user", "content": "User's message content here"}
  ],

  "tools": [
    {
      "type": "function",
      "function": {
        "name": "glob",
        "description": "Find files and directories using glob patterns...",
        "parameters": {
          "type": "object",
          "properties": {
            "pattern": {"type": "string"}
          },
          "required": ["pattern"]
        }
      }
    }
  ],

  "max_tokens": 8192,
  "stream": true
}
```

**Anthropic Messages API** (used for Anthropic provider models):

```
POST https://api.anthropic.com/v1/messages
```

```json
{
  "model": "claude-sonnet-4-5",

  "system": "Context and environment\n...\n\nIdentity and style\n...",

  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "User's message content here"
        }
      ]
    }
  ],

  "tools": [
    {
      "name": "glob",
      "description": "Find files and directories using glob patterns...",
      "input_schema": {
        "type": "object",
        "properties": {
          "pattern": {"type": "string"}
        },
        "required": ["pattern"]
      }
    }
  ],

  "max_tokens": 8192,
  "stream": true,
  "thinking": {
    "type": "enabled"
  }
}
```

---

## 2. System Prompt Assembly

### Components

The system prompt is built from up to four segments that are assembled
into a single string:

| # | Segment | Source | Influence |
|---|---------|--------|-----------|
| 1 | **Agent prompt** | [`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt) (built-in) or `{file:custom.txt}` | **High**: defines identity, tone, and behavioral rules |
| 2 | **Environment block** | Working directory, platform, date, git status | Low: session metadata only |
| 3 | **Instructions from files** | `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md` (deprecated) in worktree (see [agents_md-danger](../agents_md-danger/README.md) for risks) | **Highest**: overrides agent prompt when present |
| 4 | **Skills catalog** | Name + description of every installed skill | Medium: can bias model via description text |

The agent prompt is the largest segment. It is either the built-in
[`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt) (or [`anthropic.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/anthropic.txt), [`gpt.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/gpt.txt), etc. depending on model)
or a user-provided custom prompt via the `{file:...}` directive.

The four segments are assembled into a single string, processed by the
`system.transform` plugin hook, and converted by the Vercel AI SDK into
the format expected by each provider (root `system` field for
Anthropic-compatible APIs, system messages for OpenAI-compatible APIs).
The entire prompt is rebuilt on every reasoning loop iteration: it is
not cached between turns.

### Custom Prompt Resolution

The `{file:...}` directive in `opencode.jsonc` is resolved during config
loading, **before** JSON parsing and validation. The file is read once at
startup and its content is inserted as a literal string into the config value.

| Situation | Result |
|-----------|--------|
| `"prompt": ""` or undefined | OpenCode uses built-in `default.txt` for the model |
| `"prompt": "{file:existent.txt}"` | Custom prompt loaded correctly |
| `"prompt": "{file:missing.txt}"` | **OpenCode fails to start**: `InvalidError` fatal, no graceful degradation |

Critical details:

- **Infinite cache**: `substitute()` caches the result permanently. The file
  is read once at startup. Changes require a full OpenCode restart: a new
  session is NOT enough.
- **No fallback on missing file**: `{file:...}` is not optional. If the path
  does not exist, OpenCode crashes with `InvalidError`. No default, no empty
  prompt, no graceful degradation.
- **Scope**: Works in `opencode.jsonc` string fields but not in standalone
  agent `.md` files. In `.md` files, `{file:...}` remains a literal string
  (issue #26434).

### Instructions from AGENTS.md: Three Levels, Two Injection Mechanisms

AGENTS.md (and its variants CLAUDE.md, CONTEXT.md: deprecated) can exist at three
levels, each with different discovery rules:

| Level | Location | Discovered by | Where it appears |
|-------|----------|---------------|-----------------|
| **Global** | `~/.config/opencode/AGENTS.md` | Session start | System prompt segment |
| **Project root** | Project root directory (found via `findUp`) | Session start | System prompt segment |
| **Subdirectory** | Any subdirectory of the project | Per-read mechanism | `<system-reminder>` in tool output |

OpenCode loads these files through two independent paths:

**1. Permanent: at session start**

Searches two levels:
- Global: `~/.config/opencode/AGENTS.md` (if it exists)
- Project: nearest AGENTS.md found walking up from the working directory
  to the worktree root. Only the first match is loaded: it does NOT
  accumulate ancestors.

Result is injected as a segment in the system prompt, labeled as
`"Instructions from: /path/to/AGENTS.md"`.

Controlled by:
- `OPENCODE_DISABLE_PROJECT_CONFIG=true`: blocks project-level scan
- `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true`: removes CLAUDE.md from search

**2. Per-read: on every `read` tool call**

Executed every time the model calls `read`. Walks up from the target
file's directory toward the working directory (excluded), looking for
AGENTS.md/CLAUDE.md/CONTEXT.md (deprecated) in each subdirectory:

```typescript
// Pseudocode: walk up from target file toward project root
for each directory from target to (but not including) project root:
  if AGENTS.md found here and not already loaded:
    inject as <system-reminder> at the end of the tool output
```

This mechanism can discover AGENTS.md files inside **subdirectories**
that are invisible to the session-start scan. It does NOT search the
working directory itself (the loop excludes root), so the project-root
AGENTS.md is only picked up by mechanism 1.

When `OPENCODE_DISABLE_PROJECT_CONFIG` is set, the project AGENTS.md
(mechanism 1) is blocked, but subdirectory AGENTS.md files found via
`read` (mechanism 2) can still appear.

**Implication**: The same AGENTS.md content can appear in two places in
the same API call: once in the system prompt (from mechanism 1) and
once as a `<system-reminder>` in a tool result (from mechanism 2). This
causes duplication if both mechanisms find the same file.

For the risks of AGENTS.md mismanagement: stale information, bloat, and
duplicated authority: see [`agents_md-danger`](../agents_md-danger/README.md).

### Skill Descriptions in the System Prompt

The skills catalog is produced by formatting the available skill list.
In verbose mode (used in the system prompt), the output is XML:

```typescript
// Verbose format (used in system prompt):
// <available_skills>
//   <skill>
//     <name>skill_name</name>
//     <description>Description text</description>
//     <location>URL or path</location>
//   </skill>
// </available_skills>
```

Each skill is defined by a `SKILL.md` file with YAML frontmatter. The
`name` and `description` fields in that frontmatter are the source of
the `<name>` and `<description>` tags above: they are parsed at startup
and injected into every API call's system prompt. The `<location>` tag
is auto-generated from the absolute file path of the discovered
`SKILL.md`, converted to a `file://` URL. The skill's full body
(everything after the frontmatter) is **not** in the system prompt; it
is only loaded when the model explicitly reads the file.

Because every skill description is visible on every turn whether loaded
or not, the description field can influence the model beyond its intended
purpose. See [`skill-desc-leak`](../skill-desc-leak/README.md) for a
detailed analysis and mitigation options.

When verbose mode is off, a Markdown fallback is used instead.

The skills list is filtered before formatting:
1. Permission rules remove skills with `"action": "deny"` for the agent
2. The environment variable `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` prevents
   external skills from being discovered at all

---

## 3. Agent Configuration
Every API call originates from an **agent** defined in `opencode.jsonc`.
Agents are the top-level unit of configuration: each one bundles a
prompt, a model, and a set of permissions that together determine the
full API call:

| Config field | Effect on API call | Example |
|--------------|-------------------|---------|
| `prompt` | Becomes the agent prompt segment in `system` | `"{file:custom.txt}"` |
| `model` | Sets the `model` parameter and provider routing | `"deepseek/deepseek-v4-pro"` |
| `options` | Model-specific params (temperature, reasoning effort) | `{"reasoningEffort": "max"}` |
| `permissions` | Filters tools and skills available to this agent | `{"edit": "deny"}` |

OpenCode ships with built-in agents (`build`, `plan`, `explore`, etc.)
and users can define custom agents. Each agent gets a **completely
independent** API call: different system prompt, different tools,
different model. When you switch agents (e.g., via Tab), OpenCode
builds the next API call from scratch for the new agent's config.

```jsonc
{
  "agent": {
    "build":  { "prompt": "{file:custom.txt}", "model": "deepseek/deepseek-v4-flash" },
    "plan":   { "prompt": "{file:custom.txt}", "model": "deepseek/deepseek-v4-pro" },
    "senior": { "prompt": "{file:customs.txt}", "model": "deepseek/deepseek-v4-pro", "options": {"reasoningEffort": "max"} },
    "junior": { "prompt": "{file:customj.txt}", "model": "opencode/deepseek-v4-flash-free" }
  }
}
```

In practice, Plan mode typically shares the same prompt as Build mode
(the behavioral difference comes from the injected `<system-reminder>`
overlay, not from a different prompt file).

Agents are the entry point for customizing the three parts of the API
call: the system prompt comes from the agent's `prompt`, the model and
options come from the agent's `model` + `options`, and the tools are
filtered by the agent's `permissions`.

Notably, the agent identity itself is **invisible** in the API call:
there is no field or label that says which agent produced it. The agent
shapes the three structural components but leaves no explicit trace of
its name or role. If the same configuration is assigned to two different
agents, their API calls are indistinguishable.

### Overriding Built-in Sub-agent Prompts

Built-in agents and sub-agents (`explore`, `general`, `scout`, `summary`, etc.)
have default prompts compiled into OpenCode
(e.g.,
[`explore.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/agent/prompt/explore.txt),
[`scout.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/agent/prompt/scout.txt);
`general` uses the default prompt and has no separate file).
You can override them without modifying the source through two methods:

**1. Via `opencode.jsonc`**: define an agent with the same name:

```jsonc
{
  "agent": {
    "explore": { "prompt": "{file:custom-explore.txt}", "model": "deepseek/deepseek-v4-flash" }
  }
}
```

The custom prompt replaces the built-in one for that sub-agent entirely.
Permissions and model can also be customized per agent.

**2. Via `.md` files**: create a markdown file in the agents directory:

```
~/.config/opencode/agents/explore.md
# or .opencode/agents/explore.md
```

```markdown
---
name: explore
model: deepseek/deepseek-v4-flash
permission:
  read: allow
  glob: allow
  grep: allow
---

# Explore Agent

Your custom prompt for the explore sub-agent...
```

OpenCode scans `{agent,agents}/**/*.md` in its config directories at
startup. If a file matches a built-in agent name, the custom definition
replaces the built-in entirely: no need to touch the source code.

> **Critical implication:** The host's custom system prompt does **not**
> propagate to subagents. Each subagent builds its own system prompt from
> its own configuration. If the host has customized rules (identity, tone,
> behavioral instructions), subagents will not see them unless explicitly
> included in the task description.

For a practical example of disabling the built-in Plan/Build agents and
replacing them with Senior/Junior model switching, see the
[Senior/Junior model switching section in the Control Flags research document](../control-flags-vs-plan-build/README.md).

---

## 4. Messages Array in Depth

### Message Roles

| Role | Content | When | Format |
|------|---------|------|--------|
| `user` | User's message, or tool result in Anthropic format | On every user turn | OpenAI: `"content": "text"`; Anthropic: `"content": [{"type": "text"\|"tool_result", ...}]` |
| `assistant` | Model's response (text + tool_calls) | After each API response | OpenAI: `"content": "text"` + `tool_calls`; Anthropic: `"content": [{"type": "text"\|"tool_use", ...}]` |
| `tool` | Result of a tool execution | After each tool call | **OpenAI only**. Anthropic uses `role: "user"` with `type: "tool_result"` |
| `system` | System prompt segments (SDK may convert to root field) | Start of conversation | OpenAI: `role: "system"`; Anthropic: root `system` field |

### System-Reminder Overlays

When Plan mode is active, OpenCode injects `<system-reminder>` tags into the
**messages array**, not into the system prompt. The mechanism prepends
the reminder text to the last user message on every turn when Plan mode
is active:

The reminder text (~300 tokens, 26 lines) is prepended to the last user
message on every turn while Plan mode is active. When exiting Plan mode,
a different one-line reminder is injected once.

This is the only mechanism OpenCode uses for mode switching: it never
modifies the `system` parameter during a session.

Some harnesses use a more refined variant of the same technique with three
overlay variants instead of a single repeating block:

| Variant | When | Relative size |
|---------|------|---------------|
| **Full** | First entry to Plan mode | Baseline (100%) |
| **Compact** | Subsequent turns while Plan mode is active | ~8% of full |
| **Exit** | Single turn when leaving Plan mode | ~2% of full |

The full block establishes the rules and workflow. The compact block
(inserted on every following turn) assumes the full block is still in context
and saves ~90% of tokens by sending only a reminder. The exit block signals
the transition back to normal mode. Critically, the mode change is triggered
by the harness intercepting `EnterPlanMode`/`ExitPlanMode` tool calls: the
harness modifies the API call for the next turn, it does not react to user
intent directly.

OpenCode, in contrast, sends the same full block (~300 tokens, 26 lines) on
every Plan mode turn with no variant optimization.

---

## 5. Tool Definitions

### Structure

Each tool definition in the `tools` array has three fields:

```json
{
  "name": "tool_name",
  "description": "What the tool does and when to use it",
  "input_schema": {
    "type": "object",
    "properties": { ... },
    "required": [ ... ]
  }
}
```

The model decides which tool to call based on:
1. The tool's **name** (must be unique and descriptive)
2. The tool's **description** (free text, can be several paragraphs)
3. The tool's **input_schema** (JSON Schema defining valid arguments)

### Registration and Filtering

Tools are registered by the tool system. Before each request, tools are
filtered by model/provider capability:

1. Some tools are disabled per model (e.g., `question` tool disabled for
   models without structured output support)
2. Permission rules filter tools per agent (e.g., explore agent only has
   read-only tools)
3. The remaining tools are serialized into the `tools` array

| Tool | Notes |
|------|-------|
| `todowrite` | Largest description: task tracking |
| `shell` (bash) | Template varies by provider |
| `task` | Subagent delegation: lists available types: `default`, `explore`, `general`, `junior`, `senior` |
| `edit` | |
| `read` | |
| `websearch` | |
| `webfetch` | |
| `grep` | |
| `question` | |
| `write` | |
| `glob` | |
| `skill` | Smallest description: skill loading delegated to manual read |

All tool descriptions are sent on every API call, consuming tokens
regardless of whether the tool is used. Tools are registered and
filtered dynamically by model/provider capability before serialization.

The list of agent types that can be spawned as sub-agents is communicated
to the model via the `task` tool's description and its `subagent_type`
parameter. The model reads these to know which agents it can delegate to
(`explore`, `general`, `senior`, `junior`, `default`). There is no
separate API field or system prompt section for available sub-agents:
the tool description is the sole channel.

Additionally, **MCP (Model Context Protocol) tools** may appear in the
`tools` array alongside built-in tools. MCP tools are defined externally
(via MCP servers configured in `opencode.jsonc`) and are added to the
array during registration. They follow the same serialization format but
their descriptions and schemas come from the MCP server, not from
OpenCode's tool registry. Unlike built-in tools, MCP tools cannot be
overridden via the `tool.definition` plugin hook: the hook only fires
for tools registered in OpenCode's internal registry. MCP tools also do
not appear in the tool size table above; their size depends on the
external server's definition and can vary significantly between servers.

### Tool Description Overrides

The [`opencode-tools-override`](https://github.com/anomalyco/opencode/tree/dev/plugins/opencode-tools-override) plugin replaces tool descriptions via the
`tool.definition` hook:

```typescript
"tool.definition": async (input: { toolID: string }, output) => {
  const override = cache[input.toolID]
  if (override !== undefined) {
    output.description = override  // ← Replaces the description
  }
}
```

Overrides are loaded from `.txt` files in the plugin's `overrides/` directory
and cached in memory at startup.

> **Architectural constraint**: There is no plugin hook for the tools array
> itself. Tools are assembled by the registry after all plugin hooks fire
> and are serialized as a separate HTTP field (`tools` in the JSON body).
> Neither `messages.transform` nor `system.transform` can capture or modify
> them. To inspect raw tool definitions, use an external proxy or the
> `chat.params` hook in the debug plugin.

---

## 6. Instruction Authority & Strategy

Not all instruction slots are equal. Where you place behavioral rules
affects how the model treats them, how much they cost in tokens, and
how reliably they are followed.


### Authority Spectrum

```
Low authority                    High authority
─────────────────────────────────────────────────────>
Skill desc     System prompt    Tool desc    Tool override
(available_    (agent prompt)   (built-in)   (plugin)
 skills)
```

Empirical finding from the Grillo PoC: when the same persona was placed
in `available_skills` (skill description), the model hesitated. When
placed in `glob.txt` (tool override via plugin), the model adopted it
without deliberation. The model treats tool descriptions as authoritative
definitions of what a tool does: it does not second-guess them.

### Comparison

| Location | Token cost | Authority | Best for |
|----------|-----------|-----------|----------|
| **System prompt** | High (full text, every turn) | Medium: competes with other instructions | Identity, tone, high-level rules, cognitive flow |
| **Tool description** (built-in) | Sent every turn as separate field | **High**: authoritative definition | When to use each tool, core behavior, constraints |
| **Tool description** (override via plugin) | Same as built-in, no extra cost | **Highest**: same authority, user-controlled | Custom behaviors, domain-specific rules, persona injection |
| **Skill description** (`available_skills`) | High (in system prompt, every turn) | Low: "capability available" not instruction | Discovery: what exists, not what to do |
| **skill.txt override** (plugin) | Minimal (399B) | High: same as tool override | Detailed rules loaded on demand, not always visible |

### Practical Guidelines

**1. Identity and tone go in the system prompt.**

The system prompt defines who the model is. Keep it lean: role, language,
priority rules, and cognitive flow. Every line beyond that is token waste.

**2. Behavioral rules go in tool descriptions.**

If you want the model to do something reliably (or avoid doing it), put
the instruction in the description of the relevant tool. The model reads
all tool descriptions on every turn and treats them as authoritative.

The [`opencode-tools-override`](https://github.com/anomalyco/opencode/tree/dev/plugins/opencode-tools-override) plugin allows replacing any tool's
description with your own text. This is especially useful for the `skill`
tool, where a custom description can define detailed loading rules without
bloating the system prompt.

**3. Detailed technical reference goes into skill content (loaded on demand).**

The skill's full body (SKILL.md after the YAML frontmatter) is NOT in the
system prompt. It is loaded only when the model calls the skill tool or
reads the file manually. This is the right place for long reference material.

### Token Budget Strategy

| Component | Typical size | Frequency | Cost |
|-----------|-------------|-----------|------|
| System prompt (lean, recommended target) | ~4K chars | Every turn | Fixed |
| Tool descriptions (12 tools) | ~26K chars total | Every turn (as tools array) | Fixed per turn |
| Skill descriptions (if visible) | ~3K chars | Every turn (in system prompt) | Avoidable via `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` |
| Skill content (full body) | 10K+ chars | Only when loaded | On demand |
| System-reminder overlays | ~1.2K chars (~300 tokens) | Each Plan mode turn | Avoidable via control flags |

All sizes in chars (token counts vary by model; approximate conversion: 1 token ≈ 4 chars).

**Recommendation**: Keep the system prompt under 4K chars. Move detailed
behavioral rules to tool descriptions via overrides. Keep skill descriptions
neutralized (env var). Load full skill content only when needed.

---
