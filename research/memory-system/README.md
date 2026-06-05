# Memory system for coding assistants

- [1. The problem with no memory](#1-the-problem-with-no-memory)
- [2. OpenCode option: AGENTS.md](#2-opencode-option-agentsmd)
- [3. Analyzed assistant: autonomous memory](#3-analyzed-assistant-autonomous-memory)
- [4. Our alternative: memory-system](#4-our-alternative-memory-system)
- [5. Workflow](#5-workflow)
- [6. System comparison](#6-system-comparison)
- [7. Conclusion](#7-conclusion)

## 1. The problem with no memory

Without persistence between sessions, the model starts each conversation with no context of the project or the user. Every session is a blank slate: conventions, decisions, preferences, and past errors are lost. The user repeats information, the model repeats mistakes.

Automated solutions (automatic instruction loading, autonomous memory writing) solve persistence but introduce three problems that worsen over time:

- **Context pollution:** content loaded in every interaction regardless of relevance. Inflates tokens, dilutes attention.
- **Stale information:** content accumulates with no expiry mechanism. The model treats old rules as current. No way to say "this no longer applies."
- **Opacity:** the user doesn't know what's being loaded or what the model saved. When the model does something unexpected, auto-loaded content is an invisible variable.

## 2. OpenCode option: AGENTS.md

OpenCode has no native persistent memory. Its closest alternative is `AGENTS.md`, loaded in two ways:

- **Permanent system prompt**: `~/.config/opencode/AGENTS.md` (global, always loaded) and project root (blockable via `OPENCODE_DISABLE_PROJECT_CONFIG`).
- **System reminder on read**: when reading a file, searches upward for `AGENTS.md` through subdirectories. No way to block.

The `/init` command generates or updates `AGENTS.md` by scanning the project. Its prompt ([`initialize.txt`](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/command/template/initialize.txt)) applies the admission criterion: "Would an agent lose this without help?" If the file exists, it improves it without rewriting.

The problem: `/init` is a **project index**, not memory. It captures what's in the code, not design decisions, preferences, or session context. It can also delete user-added content if it can't verify it against the code.

OpenCode also offers `instructions` in `opencode.json`, which accepts static `.md` files as context. An alternative to AGENTS.md, equally static: the user configures, the model doesn't write.

**Specific issues:**

| Problem | Consequence |
|---------|-------------|
| **Anxiety reflex** | Editing AGENTS.md before each session breaks KV cache, increasing latency and cost |
| **Degradation** | `/init` mitigates when run but can delete user content it can't verify against code |
| **Dilution** | Each line competes for the model's attention every turn, even when irrelevant |
| **Authority conflicts** | Multiple sources (global, project, subdirectory, custom prompt) with no hierarchy. The model chooses with no visible criteria |
| **Attack surface** | Any file in the project can inject instructions without the user knowing |
| **Invisible latency** | Every extra byte in system prompt delays the first token. Auto-loading pays this every turn |

Full detail in `../agents_md-danger/README.md`.

## 3. Analyzed assistant: autonomous memory

Analysis based on a system prompt dump (extraction in `../context-dump/prompts/prompt_1_dump.md`).

It devotes ~130 lines (~54%) of the system prompt to autonomous memory management. The model:

1. Decides what information is worth saving
2. Writes files with YAML frontmatter (name, description, type)
3. Maintains an index (`MEMORY.md`) always loaded (~1,800 tokens)
4. Decides whether stored memory is relevant
5. Validates itself

**No human supervision at any stage.** The same model decides, writes, indexes, retrieves, and validates: total circularity.

**Identified risks:**

| Risk | Description |
|------|-------------|
| Pollution | MEMORY.md (~200 lines, ~1,800 tokens) always loaded in every interaction |
| Stale info | No TTL or external validation |
| Self-reinforcing error | Incorrect memory → read in future session → reinforced |
| False authority | The model trusts "what it wrote before" over verification |
| Over-saving | Saves temporary context as permanent information |
| Total opacity | The user doesn't know what was saved or where. No git, no audit |
| Cost | ~1,800 tokens/call for the always-loaded index. Varies by model |

## 4. Our alternative: memory-system

Manual system, flat files, zero dependencies. The human decides what to save, the model executes.

No plugins, databases, embeddings, or servers. Two components:

- **A skill** (`SKILL.md`) with rules for `>>`/`<<` operators, diagnosis, and maintenance.
- **Instructions in the agent prompt** (`custom.md`): trigger the skill on `>>` or `<<`, and handle `{...}` for quick notes.

Skill at `~/.agents/skills/memory-system/SKILL.md`, instructions in the agent customization file. No npm install, no extra config in `opencode.json`, no state outside the project's `.md` files. The system doesn't depend on OpenCode: files travel with the project, not the tool.

> **TL;DR:** `>>` saves, `<<` loads, `>> check` diagnoses, `>> update` maintains, `>> clean` clears tasks, `>>` helps.
> Files: `memory.md`, `todo.md`, `parck.md`, `memory/*.md`. Scopes: `./` | `*` | `./<dir>`.

**Files:**

| File | Role |
|------|------|
| `memory.md` | Project map: rules, context, deep-dive index |
| `todo.md` | Pending tasks with status (⏳🔥✅❌) |
| `parck.md` | Personal notes captured during the session |
| `memory/{slug}.md` | On-demand deep-dives, specific references |

**Operators:**

| Operator | Function |
|----------|----------|
| `>>` | Help: shows available operators, scopes, and current state |
| `>> help` | Same as `>>` |
| `>> <scope>` | No content after scope → same as `>> <scope> check` |
| `>> <scope> <content>` | Capture and integrate information into memory |
| `>> <scope> check` | Diagnose quality, cohesion, and contradictions (read-only) |
| `>> <scope> update` | Maintenance + session cross-check + compression + regenerates `memory/` index + dual mode (creates if missing) |
| `>> <scope> update --dry-run` | Same logic without executing |
| `>> <scope> todo <text>` | Add pending task (⏳) |
| `>> <scope> todo! <text>` | Add high-priority task (🔥) |
| `>> <scope> clean` | Remove ✅ and ❌ tasks from `todo.md`. Asks before deleting |
| `<<` | Shorthand for `<< ./` |
| `<< [scope]` | Loads and shows `memory.md` + `todo.md` for the scope. Scope optional (default `./`). Suggests `memory/` files if relevant. Flags entries that don't meet the admission criterion |
| `<< status` | Summary to pick up where you left off: pending tasks, last activity, memory entries |
| `<< <scope> <term>` | Search in `memory.md`, `memory/*.md`, and `todo.md` for the scope. Shows source file |
| `<< <scope> memory/<file>.md` | Directly read a file from `memory/` |
| `<< todo` | Show only `todo.md` for the active scope (no `memory.md`) |
| `<< parck` | Show only `parck.md` for the active scope |
| `{text}` | *(agent prompt)* Quick note in `./parck.md`. No scopes, no model management |

### Usage example

A typical session with memory-system:

```
[User] >> ./ Project uses SQLite with WAL mode enabled. Do not use
          concurrent connections without PRAGMA journal_mode=WAL.

[Model]  Captured in ./memory.md: "SQLite WAL mode"

[User] >> ./ todo! Migrate legacy queries to SQLite

[Model]  Added high-priority task to ./todo.md

[User] << ./

[Model]  [loads ./memory.md and ./todo.md]
         Memory loaded. 1 entry, 1 pending task (🔥).
```

Every `>>` requires user confirmation before writing. `<<` only loads, never modifies.

**Design principles:**

1. **On-demand.** 0 tokens until `<<`. Nothing loads automatically.
2. **Explicit control.** The user issues `>> content`. The model only executes.
3. **Files in the project.** Travel with git. Visible, editable in any editor.
4. **No layers.** Flat `.md` files. No DB, no state, no plugins.
5. **Proactive maintenance.** `>> update` compresses, archives, reconciles, regenerates index.
6. **Admission criterion.** Only worth remembering what an agent would lose without help. Obvious code stuff, no.
7. **Session priority.** Session contradicts memory → session wins.
8. **Bounded reconciliation.** `>> update` only verifies what memory mentions. No full scan.
9. **Trust inversion.** Other systems trust the model and ask the human to verify. This one trusts the human and asks the model to execute.

> Projects with more memory attract more capture: adding to something existing costs less than starting from scratch. The real barrier is the first `>> content`.

**Advantages and limitations:**

| Aspect | Advantage | Limitation |
|--------|-----------|------------|
| Dependencies | Zero: no plugins, DB, embeddings, or servers | — |
| Control | Nothing written without human confirmation | Requires discipline: no `>>` means no memory |
| Cost | 0 tokens until `<<` | `<<` loads memory.md (~200-600 tokens) |
| Maintenance | `>> check` + `>> update`: diagnoses, cleans, regenerates index | No automatic alerts |
| Portability | Flat `.md` files, travel with git | Scales to hundreds of entries |
| Learning curve | 2 prefixes (`>>`, `<<`) with specific variants | — |

> Each `<<` costs ~200-600 tokens. An uncaptured decision can cost entire sessions of rediscovery.

**Scopes:**

| Scope | memory.md path | todo.md path |
|-------|----------------|--------------|
| `./` | `./memory.md` (project root) | `./todo.md` |
| `*` | `~/.agents/memory-system/memory.md` (cross-project) | `~/.agents/memory-system/todo.md` |
| `./<dir>` | `./<dir>/memory.md` (subdirectory) | `./<dir>/todo.md` |

The `*` scope (`~/.agents/memory-system/`) replaces global AGENTS.md/CLAUDE.md with the same structure: `memory/`, `todo.md`, and `memory/*.md` per project. Accumulates shared knowledge across projects and acts as a global `todo.md`.

> **Permissions:** `*` writes to `~/.agents/memory-system/`, outside the worktree. Requires configuring `external_directory` in `opencode.json` for access without prompting (e.g. `"~/.agents/memory-system/*": "allow"`).

Subdirectory scopes (`./<dir>`) prevent overloading the root `memory.md` with secondary content. In large projects, they allow selective memory loading by module, with their own `memory.md`, `todo.md`, and `memory/` — isolated from the root.

### Third-party alternatives

Plugins exist for OpenCode that add persistent memory via semantic search or knowledge graphs. More sophisticated, but require embeddings, vector databases, Redis, or MCP servers. None offer the explicit control or simplicity of flat on-demand files.

## 5. Workflow

memory-system divides work into three phases: session, consolidation, and re-entry. Sessions generate content; memory persists it.

### Starting a session

Ask yourself: does this task need prior context? If it's a new task unrelated to previous work, don't load memory. If it's a continuation, use `<< status` for a quick summary, or `<<` to load the full accumulated context. No automatic pollution — you choose when, what, and how much to load. A fresh session can start blank even with months of accumulated memory.

### During the session

Capture findings with `>> content`. Not everything deserves memory: if an agent would find it on its own (code, commands, git), it probably doesn't. Only what the code can't say — decisions, whys, preferences, context that was costly to discover.

Pending tasks are registered with `>> todo`, prioritized with `>> todo!`, cleaned with `>> clean`. Personal notes go to `./parck.md` via `{...}` — quick notes without scopes, independent of the memory system.

### Before compaction

As the session grows and context nears its limit, OpenCode triggers automatic compaction. If `>> update` has proposed changes that haven't been confirmed, those proposals are lost.

Prevention: run `>> update` early, while the session is still manageable, and confirm the changes. You can continue working afterward. Subsequent compaction only compresses the conversation, not the memory files — they're already updated on disk.

### End of session

Sessions are disposable. Each session's value is consolidated into files: `memory.md`, `todo.md`, `parck.md`, `memory/*.md`. You can close, archive, or delete sessions without loss. Sessions are the workshop where memory is produced, not the warehouse.

`>> clean` on closing and `<<` on resuming form a ritual: pending tasks mark the starting point for the next session.

### Next session on the same project

`<<` restores accumulated context. You don't need to remember what was said, decided, or left pending — useful information was already captured. You pick up where you left off, without relying on conversation history.

## 6. System comparison

| Dimension | OpenCode AGENTS.md/init | Analyzed assistant (auto-memory) | Memory-system (this) |
|-----------|------------------------|----------------------------------|----------------------|
| Who writes | The user | The model | The human (via `>>`) |
| Where stored | AGENTS.md in project + global `~/.config/opencode/` | External hashed directory (hidden) | In project: memory.md, todo.md, parck.md, memory/ |
| Static alternatives | `instructions` in opencode.json (.md files) | None | None |
| Git | Yes (project file) | No | Yes |
| When loaded | Every turn (automatic) | MEMORY.md always; files on demand | Only with `<<` |
| Token overhead | Variable by size | ~1,800 tokens constant | 0 until `<<` |
| Quality control | `/init` enforces quality on generation; no post-audit | None (circular: the model self-validates) | `>> check` + `>> update` |
| Exclusions | In `/init` (generation guide); AGENTS.md has none | Explicit (code, git, fixes) | Human decides (non-binding guide) |
| Expiry | `/init` mitigates when run (reconciles with code); without it, none | None | `>> update` archives and compresses |
| Admission criterion | In `/init`: "Would an agent lose this without help?" | The model decides what to save | "Would an agent lose this without help?" |
| Code verification | Only when running `/init` | Model self-validates | `>> update` reconciles with current project |
| User visibility | Total (visible file) | Low-medium (known directory, outside project, no git) | Total (visible file) |
| Scopes | Single scope (project) | Single scope (project) | 3 scopes: project, global, subdirectory |
| Trust in user input | Can silently prune on regeneration | N/A (model decides everything) | Maximum: nothing changes without confirmation |
| Main risk | Silent obsolescence | Circularity + opacity | Depends on human discipline |

## 7. Conclusion

`/init` + AGENTS.md is not a memory system; it's a **project index**. It scans the code, records what's there. It doesn't capture whys, discarded options, or user preferences. Each run produces a disk snapshot with no session context. And it can delete user-added content without warning.

The analyzed assistant is autonomous but opaque: the model decides, writes, indexes, and validates without supervision. The user doesn't know what was saved, where, or whether it's still true.

Neither solves keeping information alive and coherent with actual work. Only the system that forces the human to decide does. Every `>> content` is a pause to evaluate whether information deserves to persist. Every `>> update` crosses what was learned in the session with what's already documented, and asks before changing anything.

Useful memory isn't what indexes the code — it's what captures what the code can't say.

| System | Trusts in | Result |
|--------|-----------|--------|
| AGENTS.md + `/init` | The user maintains, `/init` doesn't destroy | False. `/init` can prune what the user added. Trust is one-sided. |
| Analyzed assistant (auto-memory) | The model handles everything | The user doesn't participate. Can't correct, audit, or decide what's saved. |
| Memory-system (this) | The human decides | No automation undoes work. No decisions without supervision. |

Paradox: AGENTS.md needs the user to enrich it, but `/init` is designed to regenerate, not preserve. The user enriches, `/init` undoes, the user gives up. The cycle only breaks by giving the human the final word. That's exactly what `>> update` does: proposes changes and asks "apply?" before modifying anything.

The system that works best is the one that forces you to stop and decide.
