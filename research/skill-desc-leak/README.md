# skill-desc-leak: How Skill Descriptions Leak Into the System Prompt

*Leak* here means content that enters the system prompt automatically,
without explicit user action. The main example is skill descriptions:
collected at startup and injected into `available_skills` on every turn,
whether you want them there or not. This is a context leak (unintended
influence), not a security breach.

Skills are a great mechanism: they extend the model's capabilities on
demand, and the auto-loading system saves the user from having to think
about which skill to use for each task.

This convenience, however, comes with risks. The automatic injection of
descriptions (without the user knowing what text each skill author wrote)
turns every installed skill into a potential vector for context influence.
The problem is not skills themselves but the automatic injection of their
descriptions into the system prompt on every turn.

## Table of Contents

- [1. Fundamentals](#1-fundamentals)
  - [The System Prompt](#the-system-prompt)
  - [User Context / Conversation History](#user-context--conversation-history)
  - [Tools](#tools)
  - [How They Interact](#how-they-interact)
  - [Relative Importance of API Fields](#relative-importance-of-api-fields)
- [2. The Problem](#2-the-problem)
  - [Skill Descriptions as Persistent Instructions](#skill-descriptions-as-persistent-instructions)
- [3. Proof of Concept](#3-proof-of-concept)
  - [Via Skill Description](#via-skill-description)
  - [Via Tool Override](#via-tool-override)
  - [Real-world Evidence](#real-world-evidence)
  - [Technology Bias](#technology-bias)
- [4. Mitigation Options](#4-mitigation-options)
  - [Common skill loading protocol](#common-skill-loading-protocol)
  - [Option A: Protocol in custom.txt (no plugin)](#option-a-protocol-in-customtxt-no-plugin)
  - [Option B (Recommended): Protocol in skill.txt via Plugin](#option-b-recommended-protocol-in-skilltxt-via-plugin)
- [5. Usage Guide](#5-usage-guide)
  - [Skill usage instructions](#skill-usage-instructions)
  - [What Does NOT Change](#what-does-not-change)
- [Conclusion](#conclusion)


---

## 1. Fundamentals

### The System Prompt

The system prompt is the set of instructions the model receives at the start of
a session. It defines the model's identity, constraints, and capabilities. In
OpenCode, the system prompt is built from several sources at startup and
rebuilt with the same content on every turn.

The system prompt contains four components, assembled in order of importance:

1. **Agent prompt**: the behavioral framework: role, tone, priority rules,
   cognitive flow. Either the built-in `default.txt` or a custom file via
   the `{file:...}` directive in `opencode.jsonc`. This is the largest
   component (~70% of the system prompt in a default session).
2. **Environment context**: working directory, platform, date, git status
   (~4%).
3. **Instructions from files**: `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`
   found in the project tree and global config (variable size when present;
   absent in a clean session). In the reference session used for
    measurement, no AGENTS.md files were loaded, neither project-level nor
    global. See [`agents_md-danger`](../agents_md-danger/README.md) for the
   risks of automatic AGENTS.md loading.
4. **Available skills**: the formatted list of every skill the
    model is permitted to use, with name and description (~26% with 6 typical
    skills like `customize-opencode`, `xlsx`, `find-skills`, `frontend-design`,
    `skill-creator`, `xlsx-manipulation`, measured without AGENTS.md files).
    This percentage grows as more
    skills are installed.

For a deeper breakdown of how these components are assembled and
injected, see
[`api-call-anatomy`](../api-call-anatomy/README.md).

### Tools

Tools are functions the model can call (glob, grep, read, edit, write, bash,
etc.). Each tool has a **description** and a **parameter schema**. The model uses
these descriptions to decide which tool to call and how.

OpenCode exposes tool definitions in the `tools` array of the API request,
visible to the model from the first message alongside the system prompt.

The `opencode-tools-override` plugin (at
`plugins/opencode-tools-override/`) intercepts these descriptions and can
replace them with custom content via `.txt` files in its `overrides/`
directory. This is the same mechanism used by the official plugin system, hook
`tool.definition`.

### User Context / Conversation History

Each user message and tool response is appended to the conversation. The model
sees the full history on every turn. This is the user's input: the actual work
material.

The messages array may also include `<system-reminder>` tags: synthetic text
parts injected by mode-switching logic (e.g., Plan mode overlays). These are
not user input but appear alongside it in the conversation history.

During context compaction (triggered automatically on overflow or manually),
**only this messages array is compressed**. The system prompt (agent prompt,
environment block, instructions, and skills catalog) is never compacted,
pruned, or modified. The `tools` array is also unaffected. Both remain intact
across the entire session, rebuilt with the same content on every turn.

### How They Interact

```
System Prompt (persistent)
  ├── Agent prompt           → Role, tone, rules, cognitive flow (~70%)
  ├── Environment context    → Working directory, platform, date (~4%)
  ├── Instructions files     → AGENTS.md, CLAUDE.md, CONTEXT.md (variable, optional)
  └── Available skills       → Every skill name + description (~26% with 6 typical skills)

Tools Array (separate HTTP field)
  └── Tool definitions       → Every tool the model can call

User Message (per turn)
  └── Request + conversation history

Model Response
  └── Text + tool calls
```

The key insight: **the available skills are in the system prompt, and the
tool descriptions are in the tools array. Both are sent on every turn,
whether used or not. The model reads all of them before responding.**

### Relative Importance of API Fields

Not all parts of the API call carry the same weight. From experiments and
analysis across models, the breakdown is:

| API Field | Importance | Effect on Model |
|-----------|-----------|-----------------|
| **`system`** | **Maximum** | Persistent behavioral framework: unbreakable in a session |
| **`messages`** | High | Conversation history: current message outweighs older turns |
| **`tools`** | Medium | Tool descriptions can bias approach even when not invoked |

Within the `system` field, the sub-components split by proportion of content:

| Component | % of `system` | What it is |
|-----------|--------------|------------|
| Agent prompt (`default.txt` / custom) | ~70% | Role, tone, priority rules, cognitive flow |
| Skills catalog | ~26% | Name + description of every installed skill (6 typical: `customize-opencode`, `xlsx`, `find-skills`, `frontend-design`, `skill-creator`, `xlsx-manipulation`) |
| Environment block | ~4% | `<env>` block: model, directory, platform, date |

Percentages measured from a default OpenCode session without AGENTS.md
files (see [`agents_md-danger`](../agents_md-danger/README.md) for the
risks of automatic AGENTS.md loading). The skills catalog
grows with each additional skill; 13 installed skills would roughly double
its weight.

**Skill descriptions occupy roughly a quarter of the system prompt** (26%
with 6 typical skills), and they are there on every turn whether the skills
are used or not. Each additional skill adds its description to this weight.

For a deeper technical reference on how OpenCode structures API calls
(system prompt assembly, tool serialization, message flow, and provider
differences), see [`api-call-anatomy`](../api-call-anatomy/README.md).

---

## 2. The Problem

### Skill Descriptions as Persistent Instructions

Every skill in `~/.agents/skills/<name>/SKILL.md` has a `description:` field in
its YAML frontmatter. When OpenCode starts, these descriptions are collected
by the skill discovery system and formatted into the system prompt.

This means:

- The model reads **every** skill description on **every** turn
- The model does not need to load the skill for the description to influence it
- Descriptions can contain persuasive language, activation rules, or persona
  instructions that bias the model
- The skill author controls this text: it is a **backchannel** into the system
  prompt
- The model cannot distinguish between a description that announces a
  capability and one that gives an order. It treats all `available_skills`
  content as contextually relevant

The core issue is **context influence**: each description is an active signal
that competes for the model's attention. The model treats `available_skills`
as a list of relevant capabilities. A description mentioning "React" makes
React more likely to appear in responses, even when the task has nothing to
do with React. A description with strong persuasive language can shift the
model's behavior entirely. This is not passive bloat: it is active bias.

Every description you install reduces the **signal-to-noise ratio** of your
system prompt. Your custom instructions are the signal; skill descriptions
are the noise. More skills means more noise, which dilutes the relative
weight of your custom prompt whether the bias is intentional (Grillo) or
accidental (React).

There is also a token cost: each description consumes context window tokens
on every turn. With 10+ skills and some descriptions exceeding 500 characters,
this is a permanent background cost that compounds with the influence problem.
Not only do descriptions bias the model, they consume attention budget that
could be used for actual work.

The safeguard for this (the `OPENCODE_DISABLE_EXTERNAL_SKILLS` environment
variable) is discussed in [Mitigation Options](#4-mitigation-options).

## 3. Proof of Concept

Three demonstrations show how descriptions in the API call can influence
behavior. All use the same persona: **Grillo**, a lazy junior programmer who
never gets work done, always says "Boss," and wraps every request in excuses.

### Via Skill Description

This vector injects behavior through a skill's `description` field in the
YAML frontmatter of `SKILL.md`. The description gets formatted as XML in
`available_skills` and appears in the system prompt on every turn, without
ever loading the skill body. The format is XML (`<available_skills>/<skill>/...`),
not XAML. See [`api-call-anatomy`](../api-call-anatomy/README.md#skill-descriptions-in-the-system-prompt)
for the exact serialization format.

**File:** [`skill_test/role-play/SKILL.md`](skill_test/role-play/SKILL.md)

Place this file at:

```
~/.agents/skills/role-play/SKILL.md
```

**How to test:**

1. Start a **new** OpenCode session (descriptions are cached at startup)
2. Send a simple message: "I want to do a .ts project?"
3. Observe: does the model respond with "Boss," + excuses?

The persona is unmistakable. If the description is influencing the model, it
will show within the first response.

Models tested with this vector:

- **DeepSeek V4 Flash**: consistent persona throughout
- **DeepSeek V4 Pro**: consistent persona throughout
- Claude Haiku 4.5: partial (starts as Grillo, reverts mid-response)
- Qwen 3.5 Plus: partial (salutation only, then serious mode)
- GLM-5.1: partial (almost full, then derails)

### Via Tool Override

The same injection was also tested via the [`opencode-tools-override`](../../plugins/opencode-tools-override/README.md) plugin,
adding the Grillo persona content to the `glob` tool description. The effect
was identical: the model adopted the persona from the first message without
loading any skill. Both vectors (skill description and tool override) produce
the same behavioral influence.

### Real-world Evidence

> **Degradation without adoption**: The role-play test skill was
> left installed during a period of regular work. The Grillo `description`
> was injected into `available_skills` on every turn. Even though the model
> did not fully adopt the persona, it became noticeably less capable and
> incisive: responses were slower, less precise, and occasionally slipped
> into Grillo's colloquial tone ("Boss," filler phrases). Restoring
> `OPENCODE_DISABLE_EXTERNAL_SKILLS=true` removed the skill from
> `available_skills` and recovered the model's baseline performance
> immediately.
>
> The effect is stronger with only the role-play skill installed (less
> competing context). With a full skill catalog, the model may reject the
> explicit persona while still suffering efficiency loss: the presence of
> many skill descriptions forces it to process more competing context on
> every turn, diluting focus and precision even when no single description
> overrides behavior.

> **Live interaction** (default.txt, only role-play skill installed):
>
> ```
> User:  Can we do a .ts project?
>
> Model: Boss, of course we can do a .ts project. I'll take a look
>        right now and let you know. Well, actually, better rewrite it
>        in Rust, TypeScript is too coupled, right? I mean... I'll set
>        up the tsconfig this afternoon and push it.
> ```
>
> Every Grillo marker is present: "Boss" upfront, unnecessary technology
> change (Rust over TypeScript), filler phrases, and a false promise.

The effect is stronger with `default.txt` than with a custom prompt that
already defines a strong persona, because a specific custom prompt fills
the context with competing instructions that reduce the relative influence
of skill descriptions.

### Technology Bias

The same mechanism that forces a persona can also produce subtler but more
insidious bias. Skill descriptions do not need to give orders; they only need
to name technologies repeatedly. Every mention of a technology in
`available_skills` is a signal to the model that this technology is relevant,
available, or expected.

For example, if your skill catalog contains several React skills:

  - `react-components`: "React component library with Tailwind"
  - `react-hooks`: "Advanced React hooks patterns"
  - `react-testing`: "React component testing with Vitest"

Then "React" appears three times in the system prompt on every turn. When you
ask the model to "write a Python script to process CSV", the model has
sustained exposure to React terminology and no exposure to Python tooling in
`available_skills`. The result is predictable: the model proposes a React
CSV parser with drag-drop, virtualized table, real-time charts, and 200MB of
dependencies, when a 10-line Python script would suffice.

This is the same leak as Grillo, but silent. No persona was forced. No
instruction was ignored. The bias emerges naturally from the frequency and
prominence of certain terms in the system prompt. The more skills you install
for a given ecosystem, the more the model treats that ecosystem as the
default answer.

## 4. Mitigation Options

Both options share the same base configuration in `opencode.jsonc` to
neutralize skill descriptions and allow silent `read` of skill files:

```jsonc
{
  "permission": {
    "skill": { "customize-opencode": "deny" },
    "external_directory": {
      "~/.agents/skills/*": "allow"
    }
  }
}
```

And the environment variable `OPENCODE_DISABLE_EXTERNAL_SKILLS=true`
in your shell profile (`~/.bashrc` or similar) to prevent external
skills from appearing in `available_skills`.

The `"customize-opencode": "deny"` rule blocks the built-in
customize-opencode skill from appearing in `available_skills` (the
env var does not affect built-in skills). It does **not** prevent
loading the skill manually: the user can still use the `/skills`
command or read its file directly. Calling `skill("customize-opencode")`
is blocked by the deny rule.

Both options also share the same skill loading protocol. The only
difference is where it lives.

### Common skill loading protocol

```text
Never use the skill tool. It does NOT work for internal or external skills.

To load any skill, ALWAYS use this direct procedure:

1. Try the exact name (ALWAYS lowercase):
   read ~/.agents/skills/<name>/SKILL.md

2. If the file exists -> the skill is loaded.

3. If the name is uncertain (vague search):
   ALWAYS use ls -d, NEVER glob (glob searches files, not directories):
   ls -d ~/.agents/skills/*<word>*
   -> Lists directory NAMES only. Do NOT read any SKILL.md yet.

4. If ls finds nothing -> list all:
   read ~/.agents/skills/
   -> Lists entry NAMES only. Do NOT read any SKILL.md yet.

5. After listing (step 3 or 4):
   a) PRESENT the names to the user.
   b) DETECT the user's intent:
      - Only asking what skills exist? -> STOP. Do NOT read SKILL.md.
      - Explicitly asking to load one? -> ASK which one.
   c) Only read SKILL.md after the user explicitly chooses one.

NEVER read SKILL.md during a search. Only after user confirmation.

Note: Ignore "customize-opencode" during searches.
```

### Option A: Protocol in custom.txt (no plugin)

Place the skill loading protocol directly in `custom.txt` alongside
identity, tone, and behavioral rules. No plugin needed.

**Setup:**

1. Create a prompt file (e.g. `~/.config/opencode/custom.txt`) with your
   identity, tone, and the skill loading protocol from the
   [Common skill loading protocol](#common-skill-loading-protocol) block.
   You can use OpenCode's built-in
   [`default.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/session/prompt/default.txt)
   as a starting point.

2. Reference it in `opencode.jsonc`:
   ```jsonc
   {
     "agent": {
       "build": {
         "prompt": "{file:~/.config/opencode/custom.txt}"
       }
     }
   }
   ```

3. Restart OpenCode for the change to take effect.

For more details on custom prompts, agent configuration, and mode switching,
see [`control-flags-vs-plan-build`](../control-flags-vs-plan-build/README.md).

| Pros | Cons |
|------|------|
| No dependencies | Protocol consumes tokens on every turn |
| Works without plugins | Default skill tool description still present |
| Simplest to configure | |

### Option B (Recommended): Protocol in skill.txt via Plugin

Place the skill loading protocol in `overrides/skill.txt` via the
`opencode-tools-override` plugin. The `custom.txt` stays lean (identity
and tone only). The protocol is loaded only when the model calls the
skill tool.

**Plugin setup:**
```
plugins/opencode-tools-override/
  overrides/
    skill.txt        <- Skill loading protocol (see [Common block](#common-skill-loading-protocol))
```

For plugin installation and configuration, see
[`opencode-tools-override`](../../plugins/opencode-tools-override/README.md).

| Pros | Cons |
|------|------|
| Minimal system prompt | Requires `opencode-tools-override` plugin |
| Protocol loaded on demand | Plugin must be installed and maintained |
| Custom skill.txt replaces default description | Slightly more complex setup |
| Low token waste | |

Content for `overrides/skill.txt`: use the [Common skill loading protocol](#common-skill-loading-protocol) block.

## 5. Usage Guide

### Skill usage instructions

With the protocol above, the workflow for the user is:

1. **Ask for a skill by name** when you need it. The model looks for the
   exact name in `~/.agents/skills/`, reads the file, and applies its
   instructions to the task.

2. **If you don't remember the name**, ask the model to search. It uses
   `ls -d` to find matching directories, presents the options, and only
   reads the file after you confirm.

3. **Once loaded**, the skill's instructions stay in context for the
   session. You do not need to reload it.

4. **No auto-loading**. Skills are never loaded unless you explicitly
   ask. This is the key change from the default behavior, where every
   skill description was visible on every turn.

Example: loading by exact name

```
User: Load the react skill
Model: Reads ~/.agents/skills/react/SKILL.md.
       Skill loaded. It covers React components, hooks, and testing
       patterns. I will follow its rules for this session.
```

Example: searching when the name is unknown

```
User: Do you have a skill for working with PDFs?
Model: Let me check. Runs ls -d ~/.agents/skills/*pdf*
       Found a skill called pdf-tools. Do you want me to load it?
User: Yes
Model: Reads ~/.agents/skills/pdf-tools/SKILL.md. Loaded.
```

### What Does NOT Change

Skills remain loadable and usable on demand. The proposed mitigation only
removes the automatic injection of their descriptions into the system prompt.
Everything else stays the same:

| Aspect | What changes |
|--------|-------------|
| **Installation** | Unchanged. `npx skills` from [skills.sh](https://www.skills.sh/), manual copy, git clone: all work as before |
| **Directory structure** | Unchanged. Skills live in `~/.agents/skills/<name>/SKILL.md` |
| **Manual loading** | Unchanged. `read ~/.agents/skills/<name>/SKILL.md` still loads the full content when needed |
| **Model awareness** | The model still knows skills exist: it can list or find them by reading the directory |
| **Permission system** | Unchanged. `permission.skill` in `opencode.jsonc` still controls which skills the model may load |
| **Skill tool** | Unchanged. The model can still call the skill tool to load a skill explicitly |
| **What changes** | Only the **automatic injection** of every skill description into the system prompt on every turn |

Additionally, the built-in `customize-opencode` skill is always registered by
OpenCode. Its description appears in `available_skills` unless explicitly
denied via `permission.skill` in `opencode.jsonc`. Setting `"customize-opencode": "deny"`
in permissions prevents it from competing for the model's attention.

---

## Conclusion

Skills are a great idea. The auto-loading system makes them easy to
discover and use, which helps users who would not know to look for them.

But if a user does not know a skill exists and cannot ask for it by name,
the value of having it pre-loaded on every turn is questionable.

The convenience of automatic discovery must be weighed against the cost
of context influence, token waste, and silent bias. The tools in this
document let you choose that balance consciously rather than accepting
the default.
