# opencode-tools-override

Override OpenCode tool descriptions using plain `.txt` files.
Useful for correcting instructions irrelevant to your workflow
(e.g. "use gh" when you use GitLab), removing guides for tools you
do not use, or shortening verbose descriptions (saves tokens as a
secondary benefit).

**Key advantage**: Tool descriptions carry higher authority than system
prompt instructions. The model treats them as authoritative definitions
— it adopts behaviors placed in tool descriptions more readily and
with less hesitation than the same instructions in the system prompt.
This makes tool overrides the ideal place for behavioral rules, domain-
specific constraints, and custom workflows.

See [System Prompt vs Tool Descriptions](../../research/api-call-anatomy/README.md#6-instruction-authority-strategy)
for the full analysis.

## How it works

When OpenCode prepares tool definitions for the LLM, the plugin checks
whether a `<toolID>.txt` file exists in `overrides/`. If it does, that
text replaces the built-in description. Otherwise, the original is left
untouched.

Descriptions are **cached in memory** when OpenCode starts. If you create
or modify a `.txt` file, you must restart OpenCode for the change to apply.

See the `ref/` directory for the original descriptions of all tools.

## Requirements

- OpenCode capable of loading plugins from `~/.config/opencode/plugin/` — no need to
  edit `opencode.json`.

## Installation

```bash
cd plugins/opencode-tools-override
./opencode-tools-override.sh init        # create overrides/ and capture ref/
./opencode-tools-override.sh install     # create plugin symlink
# restart OpenCode
./opencode-tools-override.sh status      # confirm plugin is active
```

## Creating overrides

Each `.txt` file in `overrides/` must be named after the tool ID.
(`overrides/` lives next to the plugin's `.ts` file — see [Files](#files).)

```bash
echo "short description for todowrite" > overrides/todowrite.txt
echo "description without git guides" > overrides/shell.txt
```

An empty `.txt` file clears the tool's description entirely.
For `task` and `skill` tools, only the auto-generated part remains.

## Commands

| Command | Function |
|---------|----------|
| `init` | Create `overrides/`, `last/` and capture current tools to `ref/` |
| `install` | Create plugin symlink at `~/.config/opencode/plugin/` |
| `uninstall` | Remove the symlink (does not touch `overrides/`) |
| `capture` | Download tools for the installed version → `ref/` |
| `fetch` | Download tools from the latest release → `last/` |
| `update` | Fetch + auto-promote if no overrides affected, block otherwise |
| `diff` | Compare `ref/` vs `last/` (auto `--impact` if overrides exist) |
| `diff --impact` | Only changes affecting tools that have an override |
| `diff --all` | Full diff of all changes (skip auto-impact) |
| `promote` | Copy `last/` → `ref/` (validate and adopt) |
| `status` | Show versions, plugin status, and active overrides |
| `help` | Full help |

### Workflow for a new OpenCode version

Quick (auto-promote if safe):

```bash
./opencode-tools-override.sh update
```

Manual (full control):

```bash
./opencode-tools-override.sh fetch              # download new tools to last/
./opencode-tools-override.sh diff --impact      # only those affecting you
./opencode-tools-override.sh diff --all         # all changes (skip auto-impact)
# review whether your overrides are still valid
./opencode-tools-override.sh promote            # adopt the new version
```

## Files

All paths relative to the plugin directory
(`plugins/opencode-tools-override/`) unless stated otherwise.

| Path | Purpose |
|------|---------|
| `opencode-tools-override.ts` | OpenCode plugin source |
| `opencode-tools-override.sh` | Manager script (init, install, capture, ...) |
| `~/.config/opencode/plugin/opencode-tools-override.ts` | Symlink → `.ts` in the repo |
| `overrides/` | Your `.txt` files with custom descriptions |
| `ref/` | Snapshot of original descriptions for the current version |
| `last/` | Downloaded descriptions from the latest release for comparison |
| `debug.log` | Runtime log (only written when `OPENCODE_TOOLS_OVERRIDE_DEBUG=1`) |

## Debugging

Set `OPENCODE_TOOLS_OVERRIDE_DEBUG=1` to enable plugin logging.
All messages (startup diagnostics and per-turn override applications)
are written to `debug.log` in the plugin directory.

```bash
OPENCODE_TOOLS_OVERRIDE_DEBUG=1 opencode
# After OpenCode starts and you interact, check:
cat plugins/opencode-tools-override/debug.log
```

To follow logs in real time from another terminal:

```bash
tail -f plugins/opencode-tools-override/debug.log
```

Without `DEBUG`, the plugin writes nothing — zero file I/O, zero log
entries.

Example output when enabled:

```
[opencode-tools-override] loaded 3 override(s)
[opencode-tools-override] applied override for "todowrite"
[opencode-tools-override] applied override for "shell"
```

## Notes

The plugin finds the `overrides/` directory automatically next to its
`.ts` file. You can move the repo anywhere; just run `uninstall` +
`install` to update the symlink.

## Related research

- [`research/api-call-anatomy/`](../../research/api-call-anatomy/) —
  Architectural reference of how OpenCode structures API calls, including
  how tool definitions are serialized and how this plugin's hook fits in
  the pipeline.
- [`research/skill-desc-leak/`](../../research/skill-desc-leak/) —
  Demonstrates how tool description overrides affect model behavior,
  including a proof of concept using this plugin and mitigation
  strategies that leverage it.
- [`research/context-dump/`](../../research/context-dump/) — Cross-harness
  comparison of tool definitions and system prompts; useful as external
  reference when writing or refining overrides.
