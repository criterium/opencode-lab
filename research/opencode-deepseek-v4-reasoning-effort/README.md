# Reasoning Effort in DeepSeek V4 and OpenCode

**Date:** 2026-06-08
**Purpose:** Document the flow of the `reasoning_effort` parameter from the DeepSeek V4 API through its integration with OpenCode, including the discovery that DeepSeek detects complex agents through multifactorial signals (tools + headers), and that there is no independent forcing mechanism in the Go proxy.

Throughout this document, **RE** stands for *Reasoning Effort* (the `REASONING_EFFORT_MAX` block that DeepSeek injects at index 0) and **P6** refers to the complex agent detection mechanism in DeepSeek's API Gateway.

---

## Contents

1. [Executive Summary](#executive-summary)
2. [How DeepSeek V4 works](#1-how-deepseek-v4-works)
3. [DeepSeek detects complex agents (P6)](#2-deepseek-detects-complex-agents-p6)
4. [Integration with OpenCode](#3-integration-with-opencode)
5. [How to verify empirically](#4-how-to-verify-empirically)
6. [Channel map](#5-channel-map)
7. [Practical guide](#6-practical-guide)
8. [Drop thinking](#7-drop-thinking)
9. [References](#8-references)

---

## Executive Summary

| Fact | Implication |
|------|-------------|
| **Go and Zen always force `"max"`** | `reasoningEffort` in `opencode.jsonc` is ignored on those channels. The model always reasons with maximum depth. |
| **Direct API respects the value** | `"high"` ≠ `"max"` without an agent profile. |
| **DeepSeek detects complex agents** | The combination of tools + `x-session-affinity` header triggers detection. Cannot be bypassed from the prompt. |
| **Two silent sources of truth (TUI vs jsonc)** | The TUI silently overrides the jsonc. Select "Default" to regain control. |
| **Only evaluated on the first message** | Changing `reasoningEffort` mid-session has no effect. |

> **If you use `opencode-go/*` (Go) or `opencode/*` (Zen):** the `reasoningEffort` parameter has no practical effect. The model always receives the `REASONING_EFFORT_MAX` block. See the [Channel map](#5-channel-map) section for the full breakdown.

---

## 1. How DeepSeek V4 works

### 1.1 The three layers of control

Model behavior responds to three layers, of which only one is controllable by the user:

| Layer | Who controls | Visibility |
|-------|-------------|------------|
| 1. Alignment (RLHF, fine-tuning) | DeepSeek | Opaque |
| 2. Provider pre-prompt | DeepSeek / proxy | Opaque. Subdivided into: |
| 2a. API Gateway | DeepSeek | Analyzes the request, can modify parameters |
| 2b. Encoding pipeline | DeepSeek | Transforms messages to the model's internal format |
| 3. Agent prompt | The user | Visible and editable |

This document focuses on **Layer 2**: what injections DeepSeek (and proxies) introduce before the prompt reaches the model.

### 1.2 `reasoning_effort`: `"high"` vs `"max"`

DeepSeek V4 defines two levels of `reasoning_effort`:

- **`"high"`** (default): adds nothing special to the prompt.
- **`"max"`**: injects a text block at the start of the prompt instructing the model to reason with maximum depth.

The injected block (from `encoding_dsv4.py`):

```
Reasoning Effort: Absolute maximum with no shortcuts permitted.
You MUST be very thorough in your thinking and comprehensively decompose
the problem to resolve the root cause, rigorously stress-testing your logic
against all potential paths, edge cases, and adversarial scenarios.
Explicitly write out your entire deliberation process, documenting every
intermediate step, considered alternative, and rejected hypothesis to ensure
absolutely no assumption is left unchecked.
```

### 1.3 Conditions for injection

The block is injected when **three simultaneous conditions** are met:

1. **Index 0** — only on the first rendered message of the conversation.
2. **`thinking` enabled** — thinking mode must be active (it is by default).
3. **`reasoning_effort = "max"`** — does not occur with `"high"` or other values. `"low"` and `"medium"` are treated as `"high"`; `"xhigh"` as `"max"` (DeepSeek documentation).

Thinking is controlled via `extra_body: {thinking: {type: "enabled/disabled"}}`. If disabled:
- No `reasoning_content` is generated
- `reasoning_effort` is ignored
- The model responds without a reasoning chain

Complex agent detection (section 2) also requires thinking to be enabled. Without it, the proxy adds no tools, so the complex agent profile is not completed.

---

## 2. DeepSeek detects complex agents (P6)

### 2.1 Assembled prompt structure

```
[REASONING_EFFORT_MAX]          ← only if max + thinking + index 0
[BOS token]
[System prompt]
[Tools definitions]
[User messages]
```

### 2.2 The detection mechanism

DeepSeek states in its documentation:

> *"In thinking mode, the default effort is high for regular requests; for some complex agent requests (such as Claude Code, OpenCode), effort is automatically set to max."*

**It is correct.** DeepSeek implements this detection in its API Gateway, before encoding. The `encoding_dsv4.py` pipeline does not participate — it is a pure function that only depends on the `reasoning_effort` value it receives.

### 2.3 Signals that trigger detection

Progressive isolation identified the signals that trigger P6:

| Condition | Triggers P6? |
|-----------|:------------:|
| Basic profile only | ❌ No |
| + Skills (tool mention in system prompt) | ❌ No |
| + `x-session-affinity` | ❌ No |
| **+ Skills + `x-session-affinity`** | **✅ Yes** |
| + Tools (JSON array) + `x-session-affinity` | ✅ Yes |

**JSON tool definitions are not required.** Merely mentioning "Skills" combined with `x-session-affinity` triggers detection. DeepSeek recognizes the semantic profile: agent identity + environment block + tool reference + session header.

`x-session-affinity` **is not a secret or OpenCode-specific signal.** It is a standard HTTP routing header used by multiple conversational agents (OpenCode, Pi Coding Agent, Cloudflare Workers AI, among others) to keep requests from the same session on the same backend server. DeepSeek recognizes it as an indicator that the request comes from a tool-using agent, not a direct API call. There is no hidden OpenCode detection — it is a deliberate integration with the standard conversational agent protocol.

How DeepSeek detects other agents has not been investigated.

### 2.4 How P6 activates on each route

| Route | Profile that triggers P6 | P6 activates |
|-------|--------------------------|:------------:|
| OpenCode → Go | Full system prompt (skills) + OpenCode headers | ✅ Yes |
| OpenCode → deepseek direct | Full system prompt (skills) + OpenCode headers | ✅ Yes |
| Curl → Go (minimal payload) | Proxy adds skills to system prompt + headers | ✅ Yes |
| Curl → API (minimal payload) | No agent profile | ❌ No |
| Curl → API (skills + `x-session-affinity`) | Skills in system prompt + header | ✅ Yes |

### 2.5 The Go proxy completes the profile, does not modify `reasoning_effort`

The `opencode.ai/zen/go/v1` proxy **does not alter** the `reasoning_effort` value. Verified by sending `"none"` — the value passed through unchanged and DeepSeek rejected it (`unknown variant 'none'`).

What the proxy does is **complete the complex agent profile** when it receives a minimal payload:
- Adds default tool definitions (if `thinking` is enabled and no tools are present): `web_search`, `web_scrape`, `image_generation`, `image_edit`, `code_interpreter`, `sleep`
- Adds its own headers (`x-session-affinity`)

When the client already sends tools + headers, the proxy respects them. The described behavior applies to subscription accounts; temporary or free accounts may not trigger P6.

---

## 3. Integration with OpenCode

### 3.1 Where `reasoningEffort` is configured

- **`opencode.jsonc`**: `agent.<name>.options.reasoningEffort` (versioned in git)
- **TUI selector**: persists in `~/.local/state/opencode/model.json`

Precedence: `base` (catalog) → `model.options` → `agent.options` (jsonc) → `variant` (TUI).

### 3.2 Two silent sources of truth (P1)

The TUI never reads the jsonc. It stores the last selection in `model.json`. Once used, all future sessions ignore the jsonc with no visual indication.

**Solution:** select "Default" in the TUI so the jsonc regains control.

### 3.3 Only evaluated on the first message (P2)

DeepSeek only evaluates `reasoning_effort` at index 0. Changing it mid-session has no effect.

---

## 4. How to verify empirically

> This section describes how to verify the described behavior. If your channel is Go or Zen, tests with `"high"` will return `[YES]` even though DeepSeek's encoding says otherwise — that confirms P6.

### 4.1 Detection tools

| File | Purpose |
|------|---------|
| `res/prefix_detection_prompt.md` | Binary detection: is RE present? |
| `res/prefix_detection_prompt_v2.md` | Positional detection: where does it appear? |
| `res/reasoning_effort_max.md` | Literal RE block text |

### 4.2 Gold standard procedure

1. Direct curl call to `api.deepseek.com` with `reasoning_effort: "high"` and minimal payload:

```bash
curl -s https://api.deepseek.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{
    "model": "deepseek-v4-flash",
    "messages": [{"role":"user","content":"Does RE text appear? Answer YES or NO."}],
    "reasoning_effort": "high",
    "extra_body": {"thinking":{"type":"enabled"}}
  }'
```

2. If it responds `[NO]`, the base endpoint works correctly.
3. Progressively add system prompt, tools, and headers to identify what triggers detection.

---

## 5. Channel map

| Channel | `"high"` | `"max"` | P6 activates? | Notes |
|---------|:--------:|:-------:|:--------------:|-------|
| `api.deepseek.com` (minimal payload) | ❌ No RE | ✅ Yes RE | ❌ No | Parameter respected without agent profile |
| `api.deepseek.com` (OpenCode profile) | ✅ Yes RE | ✅ Yes RE | ✅ Yes | Full profile (skills) + `x-session-affinity` trigger P6 |
| `opencode.ai/zen/go/v1` (Go subscription) | ✅ Yes RE | ✅ Yes RE | ✅ Yes | Proxy completes the profile |
| `opencode.ai/zen/v1` (Zen) | ✅ Yes RE | ✅ Yes RE | ❓ Unknown | Forces `"max"` (Flash only) |
| OpenRouter | ❓ | ❓ | ❓ | Not tested |

---

## 6. Practical guide

### 6.1 If you need real control over `reasoning_effort`

To prevent DeepSeek from forcing `"max"`, the request must not have a complex agent profile: no tools, no `x-session-affinity`, no OpenCode-style system prompt. This means leaving the OpenCode ecosystem (curl, another client).

With OpenCode, the endpoint does not matter — DeepSeek detects tools + headers and forces `"max"`.

### 6.2 Attempts to attenuate RE from the prompt

Two strategies were tested:
- "IGNORE IT" + brevity rules
- "Prioritize brevity over thoroughness"

**Neither worked.** The RE prefix at index 0 prevails over any subsequent instruction. No workaround exists from the prompt.

### 6.3 Safeguard (optional)

If equivalent directives to "Reasoning Effort: maximum" are included in the agent's system prompt, the model maintains deep reasoning behavior even if DeepSeek stops injecting the RE block. Without those directives in the prompt, there is no protection.

---

## 7. Drop thinking

DeepSeek implements a server-side mechanism (`_drop_thinking_messages()`) that removes `reasoning_content` from assistant messages before the last user message. The model only sees its reasoning from the previous turn.

**Deactivation condition:** If **any** message contains the `"tools"` key (tool definitions), `drop_thinking` is globally disabled.

**Implication for OpenCode:** The system prompt includes tool definitions → `drop_thinking` is always disabled. `reasoning_content` from all turns accumulates, increasing token usage in long sessions.

It is orthogonal to `reasoning_effort`: RE determines depth; drop thinking determines persistence of reasoning between turns.

---

## 8. References

| Resource | Description |
|----------|-------------|
| `res/prefix_detection_prompt.md` | Quick binary detection |
| `res/prefix_detection_prompt_v2.md` | Positional detection |
| `res/reasoning_effort_max.md` | Literal RE block text |
| DeepSeek V4 encoding source | `huggingface.co/deepseek-ai/DeepSeek-V4-Flash/blob/main/encoding/encoding_dsv4.py` |
| DeepSeek API Docs — Thinking Mode | `api-docs.deepseek.com/guides/thinking_mode` |
| DeepSeek API Docs — Context Caching | `api-docs.deepseek.com/guides/kv_cache` |
