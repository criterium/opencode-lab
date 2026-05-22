# AGENTS.md: Handle with Care. Auto-Loading Risks and How to Manage It

AGENTS.md (and its variants CLAUDE.md, CONTEXT.md) is a powerful mechanism
for injecting context into the system prompt. But its automatic loading
creates risks that are easy to overlook, especially when coming from models
with smaller context windows and aggressive usage limits.

> **Disabling auto-load is a temporary measure.** This document argues for
> disabling automatic AGENTS.md loading (or keeping it minimal) while you
> learn to manage it deliberately: keep it lean, review it periodically,
> and load it on demand when the task requires it. Once those habits are
> internalized, re-enable auto-load for the project level. The goal is not
> to abolish AGENTS.md, but to eliminate the hidden costs that appear when
> it is treated as a junk drawer rather than a precision tool.

## 1. How Auto-Loading Works

The system prompt is assembled from several components. AGENTS.md is
loaded through two independent paths, while the custom prompt follows
different rules:

| Component | When loaded | Cache | Location | Discovery | Where it appears |
|-----------|-------------|-------|----------|-----------|-----------------|
| `{file:custom.txt}` | Once at startup (cached permanently) | Infinite | Configurable path in `opencode.jsonc` | Via `{file:...}` directive | System prompt segment (replaces default agent prompt) |
| **Global** AGENTS.md | Each turn (re-read from disk) | Re-read each turn | `~/.config/opencode/AGENTS.md` | Session start (always, no flag blocks it) | System prompt segment |
| **Project root** AGENTS.md | Each turn (auto) or on demand (manual) | Re-read from disk | Project root (found via `findUp`) | Session start (blocked by `OPENCODE_DISABLE_PROJECT_CONFIG`) | System prompt segment |
| **Subdirectory** AGENTS.md | On read in that subtree | Per-read injection | Any subdirectory of the project | Per-read (every `read` tool call) | `<system-reminder>` in tool output |

**Session-start mechanism.** At startup, OpenCode searches for AGENTS.md
at the global config directory and then walks up from the working directory
to the project root. Only the first project-level match is loaded; it does
not accumulate ancestors. The result is injected as a segment in the system
prompt, labeled `"Instructions from: /path/to/AGENTS.md"`. This content is
re-read from disk on every reasoning loop iteration.

**The global AGENTS.md is always loaded.** Even with
`OPENCODE_DISABLE_PROJECT_CONFIG=true`, the global file at
`~/.config/opencode/AGENTS.md` is read unconditionally at session start.
The flag only blocks the project-root scan. This means the global level
has structural priority: it is always present, whether the user wants it
or not, and the user cannot disable it without deleting the file.

**Per-read mechanism.** Every time the model calls `read`, OpenCode walks
from the target file's directory up toward the project root, looking for
AGENTS.md (or CLAUDE.md, CONTEXT.md) in each subdirectory. If found and
not already loaded in the current message, it is appended to the tool
output as a `<system-reminder>` block. This mechanism can discover files
in subdirectories invisible to the session-start scan. It is never blocked
by any flag: subdirectory AGENTS.md can still leak into context even
when project-level auto-load is disabled.

The table above describes when each component is loaded from disk. The
table below describes when each level reaches the model during a
conversation and what effect that position has.

**Temporal priority: when matters as much as what.** The three levels
arrive at different times and positions, and models weigh them
differently:

| Level | When it reaches the model | Position in system prompt | Expected effect (model-dependent) | User control? |
|-------|--------------------------|--------------------------|--------------------------------------|--------------|
| **Global** | Turn 0 | After `<env>`, first instruction block | Primacy advantage within the instruction segment: may set the session's behavioural frame before project rules appear | No, always loaded |
| **Project root** | Turn 0 | After global, last instruction block before skills catalog | Possible recency advantage at the end of the user-controlled instruction segment (skills come after, but are system-generated) | Yes, `OPENCODE_DISABLE_PROJECT_CONFIG` |
| **Subdirectory** | Mid-session (on `read`) | Tool output (`<system-reminder>`) | Localised reminder, not foundational instruction; arrives too late for session framing | No, no flag blocks it |

Neither primacy nor recency consistently wins; the balance is
model-dependent. The only certainty is that the user cannot control it:
the hierarchy is determined by loading order and position, both internal
to OpenCode.

## 2. The Risks

### 2.1 The Anxiety Reflex

Models with small context windows and low usage limits train a habit:
change AGENTS.md before every session, put everything in, update it
mid-task. In those tools every character of context is valuable and
every edit helps.
This reflex carries over to OpenCode, but here it makes things worse:
the system prompt is rebuilt on every turn. Frequent edits do not save
tokens, they only break KV cache hits.

For models with disk-persisted KV cache (e.g. DeepSeek V4), each cache
miss costs more: the disk cache is also lost and the model must start
over from scratch. The very discipline that worked well in other tools
(keeping AGENTS.md always up to date) becomes a problem in OpenCode.
The harder you work to keep it current, the more cache misses you
cause.

### 2.2 Information Decay

AGENTS.md grows over time. You add a decision, a convention, a note.
You forget to remove it when it becomes outdated. The model treats
every line as current truth; it has no way to know something was
replaced.

Effect: the model follows rules that are no longer valid. Silent
problems appear in the output.

**No expiration mechanism.** AGENTS.md has no way to say "this rule no
longer applies." There is no `deprecated`, no `valid-until`, no
`superseded-by`. The only way to remove an old rule is to edit the file.
Manual loading makes the user do this regularly. Auto-loading removes
even that reason to review.

### 2.3 Attention Dilution

Every line in AGENTS.md competes for the model's attention on every
turn. A large file takes focus away from what matters and wastes
tokens. Unlike skill descriptions (which can be turned off via
`OPENCODE_DISABLE_EXTERNAL_SKILLS`), AGENTS.md has no per-file
off-switch: you either load it or disable the whole mechanism.
(`OPENCODE_DISABLE_EXTERNAL_SKILLS` prevents skills from
`~/.agents/skills/` from appearing in the system prompt. See
[skill-desc-leak](../skill-desc-leak/README.md) for details.)

**Invisible tax for the common case.** Most turns do not need the full
AGENTS.md. A quick fix in one file does not need every project
convention, but the model reads them all anyway. This is an invisible
cost on every interaction for a benefit that only happens in some of
them. Auto-loading loads everything upfront even when loading on
demand would be enough.

**Context window position matters.** AGENTS.md sits at the top of the
system prompt, before the user's actual request. In long sessions the
model may follow rules from AGENTS.md over what the user just asked,
just because they appear first. The user cannot control this order.

### 2.4 Authority Conflicts

If you already have a custom prompt (`{file:custom.txt}`), AGENTS.md
becomes a second source of rules. The model receives overlapping or
contradicting instructions from two places. It decides which one to
follow on its own; you never know which one won.

**No ranking between sources.** With three levels (global, project,
subdirectory) and two injection mechanisms (session-start and per-read),
the model gets instructions from multiple sources at the same time.
None of them have any ranking information; all appear as "Instructions
from:" with no priority. If global says "use tabs" and project says
"use spaces," the model picks one on its own, and you cannot predict
how. The result changes between models and contexts.

### 2.5 Security Blind Spots

**Attack surface.** Anyone who can write to the project (a compromised
package, a malicious PR, a `postinstall` script) can create an
AGENTS.md that auto-loads into the system prompt. The model treats it
as real instructions without the user ever knowing the file exists.
Manual loading needs an explicit `read`; the file cannot influence
the model without a deliberate action.

**Unreviewed third-party content.** Scaffolding tools, framework CLIs,
and commands like `npx create-*` or OpenCode's own `initialize` command
may create AGENTS.md files automatically. With auto-loading, this
content reaches the model without the user ever reviewing it. Manual
loading forces the user to decide if the generated content belongs in
the session.

**Exposure of sensitive data.** AGENTS.md may contain internal URLs,
access conventions, or temporary tokens. Auto-loaded, that content
appears in the system prompt of every turn, visible in session
exports, logs, or screen captures. Manual loading limits exposure to
the specific turns where the user chose to read it.

### 2.6 Debugging Friction

**Invisible variable in debugging.** When the model does something
unexpected (applies wrong rules, ignores instructions), AGENTS.md is
rarely the first thing checked. Because it auto-loads, it is an
invisible variable in every session. Manual loading makes it visible:
if the model needed AGENTS.md, the `read` call appears in the
conversation history.

### 2.7 Effort Asymmetry

Adding a rule to AGENTS.md takes seconds; reviewing and pruning the
file requires reading the entire document and judging each line. With
auto-loading, the cost of neglect is paid by the model (tokens, diluted
attention) and the user (degraded responses), not by the person who
wrote the rule. The imbalance means content accumulates without review.
Manual loading breaks this asymmetry because the user confronts the
accumulated weight every time they load.

### 2.8 Latency Overhead

Every extra byte in the system prompt increases the time the model takes
to produce the first token. AGENTS.md auto-loaded on every turn adds
this latency even when its content is irrelevant to the current task.
Loading on demand means the latency penalty is paid only when AGENTS.md
is actually needed, and only for the turn in which it is read, not for
every subsequent turn.

## 3. Why On-Demand Fixes It

Forcing the user to:
1. Stop, ask "do I need AGENTS.md right now?"
2. Load it manually with `read`
3. Be aware of what it contains and whether it is current

...is **healthy friction**. Without it, AGENTS.md becomes the "junk
drawer": information accumulates, nobody reviews it, and the model pays
the price in every response.

> **Disabling auto-load is a mandatory pause.** Forcing a manual `read`
> before AGENTS.md reaches the model creates a **stop-and-think** moment:
> the user must consider whether the file is current, whether it is needed
> for this task, and whether it risks stale information, bloat, or
> duplicated authority. This is the same friction described above,
> applied at the mechanism level rather than relying on willpower.
>
> Once that discipline is habitual, re-enable auto-load. The pause is a
> training wheel, not a permanent configuration.

## 4. Token and Cache Impact

The advantage of loading AGENTS.md on demand goes beyond cleanliness;
it has a direct token and cache cost:

| Strategy | Location in API call | Token cost per turn | KV cache impact | Hot-updatable? |
|----------|---------------------|---------------------|-----------------|----------------|
| **Auto-load** (global or project root, session start) | System prompt | **High**: full content every turn | Cache miss if content changes between turns | Yes, but each change breaks prefix cache |
| **Auto-injected** (subdirectory, per-read) | Tool results as `<system-reminder>` | **Medium**: added whenever a file in that subtree is read | Content cached as part of conversation | Yes, but adds tokens to read results |
| **On-demand** (manual `read`) | Messages (only when loaded) | **Low**: only the `read` call tokens | No cache impact (not in system prompt) | Not needed: changes are already in conversation context |
| **Fixed custom.txt** | System prompt (once) | **Fixed**: cached at startup | No changes, stable prefix | Not needed: stable |

When AGENTS.md is loaded on demand, updates made during the session do not
add token cost; those changes are already in the conversation history.
There is no need to re-send AGENTS.md on every turn. The only moment that
requires attention is the end of the session, when AGENTS.md should be
updated for future sessions.

**On-demand loading benefits even the disciplined user.** Keeping AGENTS.md
perfectly updated does not avoid cache misses; every edit between turns
still changes the system prompt, breaking prefix cache. For models with
disk-persisted KV cache (e.g. DeepSeek V4), each miss is more expensive
because the disk cache is also invalidated. Loading on demand sidesteps
this entirely: AGENTS.md never pollutes the system prompt, so cache hits
are determined only by the stable custom prompt.

## 5. Strategy and Controls

**In short: use `custom.txt` for stable rules, load AGENTS.md manually
when needed, delete global AGENTS.md, and review subdirectory versions
periodically.**

### Controls

| Variable | Effect |
|----------|--------|
| **Delete** `~/.config/opencode/AGENTS.md` | The only way to fully neutralize the global AGENTS.md. No flag blocks it, so removal is the definitive control. Keep the file absent if you do not use global instructions. |
| `OPENCODE_DISABLE_PROJECT_CONFIG=true` | Blocks auto-load of **project-root** AGENTS.md at session start. Global AGENTS.md (`~/.config/opencode/AGENTS.md`) is **always** loaded regardless of this flag. Subdirectory AGENTS.md (per-read) is also **not** blocked. |
| `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true` | Removes CLAUDE.md from the search list. A broader `OPENCODE_DISABLE_CLAUDE_CODE` also covers this and disables Claude Code skills. |
| `{file:custom.txt}` in `opencode.jsonc` | Replaces the default agent prompt with your own file |

> **Tip.** Instead of keeping a global AGENTS.md, move its content into
> `custom.txt`. The custom prompt is read once at startup and cached
> indefinitely. It does not add token cost or latency on every turn, and
> it does not compete with itself. If the content is session-specific,
> load it manually with `read` when needed.

**Setting environment variables in Linux.** Add to `~/.bashrc` or
`~/.zshrc`:

```bash
export OPENCODE_DISABLE_PROJECT_CONFIG=true
export OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=true
```

## 6. Related Research

- [`skill-desc-leak`](../skill-desc-leak/README.md): how skill descriptions
  leak into the system prompt and bias the model. Same vector, different file.
- [`api-call-anatomy`](../api-call-anatomy/README.md): how the system prompt
  is assembled, including the three-level AGENTS.md injection model.
