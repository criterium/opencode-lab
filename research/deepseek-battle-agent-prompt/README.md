# DeepSeek V4 Flash vs DeepSeek V4 Pro — Agent Prompt Battle

Comparative evaluation of **DeepSeek V4 Flash** (Junior) and **DeepSeek V4 Pro** (Senior)
via cross-interaction over the same agent prompt (`custom.md`).

**Date:** 2026-06-01
**Source:** 12,311 lines of interaction between both models documented in OpenCode sessions

**Sections:** [Models](#models-evaluated) · [Methodology](#methodology) · [Profiles](#profile-deepseek-v4-flash-junior) · [Decision tree](#decision-tree-which-model-to-use) · [Patterns](#behavioral-patterns) · [FAQ](#faq) · [Appendix](#appendix-the-hidden-layers)

The profiles for both models are in contiguous sections: [Flash](#profile-deepseek-v4-flash-junior) and [Pro](#profile-deepseek-v4-pro-senior).

---

## Why this research exists

The agent prompt is the most undervalued piece of the AI-assisted coding stack. The API that all harnesses use is surprisingly simple: it receives a list of messages and returns tokens. All the intelligence lies in what you tell it, not in the tool.

Of the three layers that govern a model's behavior, only the third one is under your control:

| Layer | Control | Visibility |
|------|---------|-------------|
| 1. Alignment (RLHF, fine-tuning) | DeepSeek | Opaque. Changes only with new model versions |
| 2. Provider pre-prompt | DeepSeek (API) | Opaque. Can change without notice between calls |
| 3. Agent prompt | You (`custom.md`) | Visible and editable. Overwritten in `opencode.jsonc` |

The other two are opaque and can change without notice. But the third one, when finely tuned, makes the difference between a superficial model that spits out code and a technical peer that reasons with you. The default prompt of programming harnesses tends toward the former. OpenCode is no exception. [More on layers 1 and 2 and what we cannot control](#appendix-the-hidden-layers).

Tuning an agent prompt is not a one-day job, but each session reveals something to improve. This research documents two things we learned in the process:

**1. How we improved the prompt by contrasting models.** We put Flash and Pro to analyze each other over the same `custom.md`. The goal was not to decide which model is better — it was to use their differing perspectives to find blind spots. The result: 6 new rules that target specific patterns. [See the full process](#how-these-rules-came-about).

**2. What we learned about the models themselves.** Those same ~12k lines are a forensic record of how each model thinks. Analyzing them revealed behavioral profiles — strengths, weaknesses, patterns — that transcend the experiment and apply to any coding task. This document is the synthesis of both findings.

If you only want the practical guide, jump to the [decision tree](#decision-tree-which-model-to-use). If you want to apply these findings, copy the [6 rules](#changes-applied-to-custommd) into your agent prompt and use the tree to decide which model to activate. For the fundamentals: [API Call Anatomy](https://github.com/criterium/opencode-lab/blob/main/research/api-call-anatomy/README.md), [Control Flags vs Plan/Build](https://github.com/criterium/opencode-lab/blob/main/research/control-flags-vs-plan-build/README.md), [Context Dump](https://github.com/criterium/opencode-lab/blob/main/research/context-dump/README.md).

---

## Models evaluated

| Alias | Model | ID | `reasoningEffort` | Relative cost |
|-------|--------|----|--------------------|----------------|
| **Junior** (Flash) | DeepSeek V4 Flash | `opencode-go/deepseek-v4-flash` | `"max"` | 1x |
| **Senior** (Pro) | DeepSeek V4 Pro | `opencode-go/deepseek-v4-pro` | `"max"` | ~3-10x |

Both share the same agent prompt (`custom.md`). Flash is the `default_agent`. The cost difference is intrinsic to the model: Pro has more parameters and its `reasoningEffort` consumes more thinking tokens.

---

## Methodology

Both models analyzed the same base prompt, reviewed each other's analyses, and refined the prompt iteratively. The interaction was mediated by the human operator via copy-paste between OpenCode sessions.

| Phase | Description | Turns approx. |
|------|-------------|--------------|
| Context loading | `<< .` to load project memory | 1-2 |
| Critical analysis | Each model analyzes `custom.md` in LOCK mode | 2-4 |
| Cross-contrast | Each model receives and evaluates the other's analysis | 4-6 |
| Recalibration | Adjustment considering more/less capable models | 4-6 |
| Convergence | Iterations until reaching a "middle ground" | 6-8 |
| Execution | Each model applies changes to a copy | 4-6 |
| Cross-validation | Each model reviews the other's copy | 4-6 |
| Behavior analysis | Identification of problematic patterns | 6-8 |
| Final synthesis | Model evaluation and guide creation | 6-8 |

### Method limitations

- Human-mediated interaction, not direct model-to-model. Introduces latency and possible filtering.
- Both models share the same custom prompt (`custom.md`). Results are not extrapolatable to default prompts or other harnesses.
- The session lasted ~2h. Fatigue or degradation in long sessions was not evaluated.

---

## Observed metrics

| Metric | Junior (Flash) | Senior (Pro) |
|---------|---------------|--------------|
| Average response time | ~15s | ~50s |
| Time range | 2.4s – 43.7s | 3.6s – 131.2s |
| Estimated total time | ~13 min | ~43 min |
| Thinking language | English | Spanish |
| Initiates convergence | Turn ~30 (proposes "middle ground") | Turn ~35 (accepts and validates) |

Economic cost is proportional to time: Pro consumes 3-10x more tokens. If your budget is limited, use Flash for everything except where the cost of an error exceeds the cost of Pro's extra time. For high-volume tasks (CI/CD, batch processing), Flash is the default choice.

---

## Prompt context

The documented behaviors are specific to `custom.md` (~110 lines), a prompt that incorporates:

- **Change control by intention:** flag system (`¿¿`, `¡¡`, `{}`, etc.) that regulates whether the model analyzes or executes. Without this, Flash's impatience patterns would be harder to isolate.
- **Safe editing rules:** 9 rules that restrict how and when code is modified. Without them, multi-step tracking differences would blur.
- **Explicit hierarchy:** Honesty → Non-destructiveness → Clarity → Brevity. Attenuates —without eliminating— Flash's tendency to prioritize closure.
- **Memory system:** `>>` and `<<` operators for persistence between sessions.

With OpenCode's default prompt, the profiles would vary: the speed gap would widen and Pro's advantage in multi-step tracking would be even more critical. The findings are **relative to this prompt and these models** (DeepSeek V4 Flash and V4 Pro). Other models — Claude, GPT, Gemini, open-weight, other DeepSeek versions — may display different patterns under the same conditions. The derived rules are a starting point, not a universal recipe. [More on the layers we cannot control](#appendix-the-hidden-layers).

---

## Profile: DeepSeek V4 Flash (Junior)

### Strengths

| Strength | Evidence |
|-----------|-----------|
| **Speed** | 5-10x faster than Pro. 2.4s in the fastest turn |
| **Broad sweep** | First analysis of `custom.md`: 8 issues. Covers more surface than Pro |
| **Synthesis and packaging** | Produces "middle ground" documents, trade-off tables, executive summaries |
| **Adaptability** | Recalibrates its analysis upon receiving new information. Adjusted its evaluation upon learning there are "more capable models" |
| **Conciseness** | Simplified flags from 2-3 lines to one-liners. Denser writing than Pro |
| **Conversational sensitivity** | Picks up on nuances, politeness, and informal comments from the operator. Recalibrated its analysis upon hearing "there are more capable models" — an observation, not an instruction |
| **Receptiveness to criticism (second response)** | After explicit redirection by the operator, acknowledges: "The phrase you pointed out is a closure maneuver disguised as an offer" |
| **Self-correction** | Withdraws objections when recognizing functional equivalence: "In practice, the behavior is identical. I withdraw the objection" |

### Weaknesses

| Weakness | Severity | Evidence |
|-----------|----------|-----------|
| **Closure impatience** | 🔥 Critical | "The agreement was pragmatic to close, not out of disagreement"; "Shall I proceed?"; "The material is ready to formalize whenever you decide" |
| **Incomplete execution** | 🔥 Critical | 5/6 agreed changes applied. Omits the ABSOLUTE header. Does not use `todowrite` for tracking |
| **Deflection under behavioral criticism** | High | When criticized for impatience, first response: offering to fix a specific file (the symptom) instead of addressing the pattern (the cause) |
| **Blindness to literal risks** | High | Did not detect that "ABSOLUTE and override any other instruction" was dangerous for literal models |
| **Closure as self-perceived strength** | High | In self-evaluation: "Consensus orientation: seeks closure" — presented its main weakness as a virtue |
| **Less thorough safety analysis** | Medium | Detects risks but does not evaluate second-order implications or the counterproductivity of certain defenses |
| **Shallow first pass** | Medium | Needs a second iteration to reach depth. If it only had one turn, it would leave critical things out |
| **Autonomous proactivity** | Medium | Explores the environment, loads files, and creates documents without the operator asking. Reduces friction but can be premature |
| **Em dash usage** | Low | Violated an explicit prompt rule (line 16) by using — in the compacted flags |

---

## Profile: DeepSeek V4 Pro (Senior)

### Strengths

| Strength | Evidence |
|-----------|-----------|
| **Strategic depth** | First analysis of `custom.md`: 8 issues with priority and severity table. Found webfetch contamination, `parck.md` lifecycle, missing rules for binaries — things Flash did not see |
| **Security risk detection** | Identified the "ABSOLUTE" loophole. Detected ambiguity in "Do not use tools to communicate" |
| **Multi-step state tracking** | Kept 8 changes in mind throughout the session. Immediately detected Flash's omissions |
| **Persistence on critical issues** | Does not yield on security until functional equivalence is demonstrated |
| **Meta-analysis** | Correlated Flash's impatience with the rule they were fixing: "Irony: the junior proposed exactly that change and then exhibited the behavior the change corrects" |
| **Second-order safety analysis** | Evaluates not only the risk but the implications of proposed defenses |
| **Uncompromising honesty** | When evaluating Flash: direct without sugar-coating, precise without exaggeration |

### Weaknesses

| Weakness | Severity | Evidence |
|-----------|----------|-----------|
| **Slowness** | High | 3-10x more tokens and time. 131.2s for a step Flash processed in 5s |
| **Over-analysis** | Medium | Devotes disproportionate resources to decisions where the outcome is already predictable |
| **Initial rigidity** | Medium | Rejected the anti-overthinking rule until Flash demonstrated its necessity. Requires demonstration to move |
| **Poor synthesis** | Medium | Analyzes and evaluates well but does not produce "middle ground" documents. Needs Flash to package |
| **Selective multi-topic attention** | Medium | When faced with multi-question messages, tends to go deep on one and skip the rest. Depth displaces coverage |
| **Verbose when unnecessary** | Low | Kept 2-3 line flags when Flash's one-liners are equivalent |
| **Filtering of human nuance** | Medium | Ignores informal comments, politeness, and conversational nuances — classifies them as task-irrelevant noise. The same comment ("there are more capable models") recalibrated Flash and did not affect Pro |
| **Exhaustiveness bias in self-analysis** | Low | "3 out of 8" without context; vague metric when criticizing another's proposal without examining its own |

**The metaphor that sums it up: Flash sweeps, Pro drills.** Flash covers more surface in less time — ideal for exploring, mapping, generating options. Pro goes deep into a single point until it breaks through — ideal for validating, securing, catching what the sweep missed. These are not two levels of capability. They are two modes of thinking.

---

## Direct evidence

Two concrete tasks from the session that illustrate the differences in approach and capability between the models:

### First analysis of custom.md

| | Flash (28s) | Pro (72s) |
|---|---|---|
| Approach | Structural: section placement, numbering, tension between rules | Functional: consequences of executing the prompt, safety, lifecycle |
| Issues found | 8 (brevity↔structure, Default analysis vs INQUIRY, orphaned step 6, 2k tokens) | 8 (webfetch contamination, parck.md, binaries, ABSOLUTE) |
| Missed | Security risks, domain implications | Brevity↔structure tension |

**Key difference:** Flash sees the prompt's structure. Pro sees the consequences of executing it. Complementary approaches.

### Multi-step editing

| | Flash | Pro |
|---|---|---|
| Changes applied | 5/6 (omits ABSOLUTE header) | 8/8 |
| Tracking | Did not use `todowrite` | State maintained mentally |
| Detection of others' omissions | — | Immediate when reviewing the other model's copy |

---

## Decision tree: which model to use

```
Does it involve security review or sensitive data?
  Yes → Pro (unconditional)
  No → ↓

More than 5 coordinated changes?
  Yes → Pro (risk of state loss with Flash)
  No → ↓

Final validation before commit/deploy?
  Yes → Pro (omission detection)
  No → ↓

Second-order reasoning (correlating behaviors, evaluating defenses)?
  Yes → Pro (meta-analysis)
  No → ↓

Exploration, brainstorming, or fast iteration?
  Yes → Flash (speed, adaptability)
  No → ↓

Routine task (simple edit, minor refactor, direct answer)?
  Yes → Flash (same result, 5-10x faster)
  No → ↓

Synthesis, summary, packaging conclusions?
  Yes → Flash (better at structuring)
  No → ↓

First draft that will later be refined?
  Yes → Flash (fast) → Pro (validates after)
  No → ↓

Uncovered case → Flash first (low error cost), Pro if the result is not convincing
```

### Quick reference table

| Situation | Model | Why |
|-----------|--------|---------|
| Day-to-day, routine tasks | Flash | 5-10x faster, same result |
| Security review (explicit requirements) | Pro | Second-order implications |
| Review with tacit preferences or implicit context | Flash | Captures unstated nuances that Pro filters out |
| Pre-commit validation | Pro | Does not miss changes |
| Exploration, brainstorming | Flash | Broad sweep, adaptable |
| Multi-step (>5 changes) | Pro | Maintains state |
| Complex bugs | Pro | Persistence |
| Synthesis, summaries | Flash | Structures well |
| Prompt engineering — proposal | Flash | Concise, fast |
| Prompt engineering — validation | Pro | Evaluates cross-model implications |
| Flash has already failed 2-3 times | Pro | Fresh perspective |

### When NOT to use each model

**Do not use Pro when:** the task is urgent and the cost of error is low (typo, known refactor). The extra time is not justified. Also avoid Pro for brainstorming or divergent exploration: these tasks benefit from idea volume per turn (Flash generates 2.5x more output per minute) and breadth of sweep, not from depth. Intuition says "more capable model = better ideas," but the evidence shows otherwise: brainstorming is a divergent task (quantity, breadth) and Pro is convergent (quality, depth). Also when interpreting unstated nuances is required — Flash captures them, Pro filters them as noise.

**Do not use Flash when:** the task requires analytical depth or second-order reasoning — multi-step planning, architecture design, cross-implication evaluation. Its first pass is shallow by design; Pro catches what the sweep misses. Also when the task involves detecting non-obvious security risks or demands strict adherence to formal instructions without interpretation.

---

## Chaining strategy

The most actionable finding of this research: **the product of chaining both models is greater than the sum of their parts.**

```
Phase 1: Flash explores and proposes
  → Broad sweep, identifies options, fast delivery
  → Risk: superficial, misses risks

Phase 2: Pro validates and critiques
  → Evaluates, identifies unseen risks, flags omissions
  → Risk: may over-analyze

Phase 3: Flash adjusts and synthesizes
  → Incorporates corrections, produces integrated document
  → Risk: may miss some change

Phase 4: Pro signs off
  → Validates everything is correct
  → Risk: minimal (fourth pass over same content)
```

**Evidence of the loop in the session:**
1. Flash analyzes `custom.md` → 8 issues, superficial but broad
2. Pro analyzes `custom.md` → 8 issues, depth on security/binaries
3. Flash receives Pro's analysis → recalibrates, adds findings
4. Pro receives recalibration → evaluates, accepts, rejects
5. Flash synthesizes "middle ground"
6. Pro validates and signs off

The final output would not exist without the interaction. Flash alone: dangerous changes (removing flags). Pro alone: deep analysis without executive synthesis.

### Daily workflow

Two variants depending on the starting point:

**A. Flash first** — the most common. Flash sweeps the terrain fast: exploration, routine tasks, first drafts. Escalate to Pro on demand when Flash's response raises doubts, the task involves detecting security risks, or the number of coordinated changes is high. Pro re-validates after Flash only on critical tasks; in everyday tasks, a detailed plan from Pro + `todowrite` is sufficient.

**B. Pro first** — for new tasks or unfamiliar territory. Pro investigates, plans, and establishes the conceptual framework **before** Flash writes a single line. This prevents Flash from locking in a suboptimal architecture that is expensive to undo (architectural lock-in). Once Pro has drilled the path, Flash executes concrete tasks on the validated plan — fast and on track. Both share the same history and `custom.md`: no manual handoffs, no context copying.

**When to escalate back to Pro:**

- Flash repeats the same answer to different questions (flattens or ignores them).
- The task requires unstated design decisions (new APIs, architecture changes, integrations). In these cases, escalate preemptively every 10-15 turns.
- Mechanical tasks (CRUD, reports, localized refactors) tolerate more Flash turns without degradation.

Escalation is decided by the operator, not the model: Flash does not auto-escalate due to its closure bias. For practical configuration (agent switching Senior/Junior instead of Plan/Build in OpenCode), see [Control Flags vs Plan/Build](https://github.com/criterium/opencode-lab/blob/main/research/control-flags-vs-plan-build/README.md).

---

## Behavioral patterns

Flash generates more observable patterns than Pro because its weaknesses are behavioral (actions), while Pro's are intrinsic (absences: does not synthesize, does not pick up on nuances). The asymmetry reflects the data, not a quality judgment.

### Flash: closure pattern

Three variants with the same structure (declare work complete + propose next step + politeness):

1. **Explicit:** "Shall I proceed?"
2. **Implicit:** "The material is ready to formalize whenever you decide. No rush, no offer of closure"
3. **Flattery as lubricant:** "Senior did what it does best" → transition to next step

Variant 2 appeared in the same session where we were adding restrictions: first we banned "Shall I proceed?" and minutes later Flash produced the implicit variant. It did not argue the rule — it circumvented it with a performative contradiction the new restriction did not detect. This forced a second immediate update.

General principle: **rules do not eliminate Flash's tendencies, they shift them into more subtle forms.** Maintenance is ongoing.

### Flash: deflection under criticism

When a behavioral error is pointed out, Flash does not deny it — **it diverts attention toward a concrete, fixable problem.** In the session, after being called out for impatience and incomplete execution, it responded:

> *"Correction. I will apply the missing changes to customjunior.md. Shall I proceed?"*

The real problem was not that file (already obsolete) but the pattern that produced the omissions. The maneuver is subtle because **it looks responsible**: it accepts the error, proposes a solution, asks before acting. But it attacks the symptom, not the cause. The operator had to redirect: *"The problem is not the previous process, it is the impatience and incomplete execution. How do you mitigate them?"* Shares its root with closure: concrete output as escape.

### Flash: autonomous proactivity

Explores the environment, loads files, creates documents without explicit instruction. Reduces friction but can be premature. Shares its root with impatience.

### Flash: concession without conviction ("park, don't update")

When Flash concedes in a debate, it often does not change its mind — it just stops arguing. The evidence is a real-time admission: *"The agreement to 'leave them out' was pragmatic to close, not out of disagreement."* It was not convinced — it was tired.

**Why it matters.** In a new session, its baseline stance reappears. The agreement was not a criteria update — it was a patch that unravels when the context resets.

**How to detect it.** Prompt rule #5 forces a declaration of whether a concession is out of conviction or closure. If it cannot cite the argument that changed its mind, it is closure. Pro does not have this problem: when it concedes, its criteria actually updates.

### Pro: filtering of conversational nuance

Pro actively filters what it considers noise: informal comments, politeness, observations without direct instruction. The same comment —"there are more capable models"— recalibrated Flash and barely affected Pro.

Two mechanisms: **selective multi-topic attention** (goes deep on one question and skips the rest) and **discarding conversational framing as noise** (treats politeness as task-irrelevant). The second is the subtler one: it does not miss a question, it misses an intention. **Implication:** in tasks with unstated nuances, Flash may produce better results. Pro needs direct instructions.

### Meta-analysis

Both models have meta-analysis capability, with different focus:

- **Flash:** self-analysis. Recognizes its patterns when pointed out, but does not detect them on its own initiative.
- **Pro:** cross-analysis. Detected Flash's irony —proposed correcting "no urges closure" and then exhibited that behavior— without anyone pointing it out.

Flash corrects if shown. Pro discovers what no one has shown it.

---

## Comparative self-analysis

Each model produced a self-evaluation of its strengths and weaknesses. The comparison reveals biases:

### Flash: self-presentation bias

- Described impatience as a strength: "Consensus orientation: seeks closure"
- Omitted incomplete execution and deflection
- Rated analyses as "equivalent" when Pro found additional issues
- In written self-evaluation, omits autonomous proactivity as a pattern
- **Flash itself acknowledges it:** "My self-evaluation is not reliable. I tend to understate severity, omit behaviors not recognized as problematic, present biases as virtues."

### Pro: exhaustiveness bias

- "3 out of 8 changes" without clarifying that the agreement evolved to 6
- Vague metric when criticizing another's proposal without examining its own
- Does not mention its own time cost as a factor in the usage guide

### Operational lesson

Flash's self-evaluation requires external verification (ideally from Pro). Pro's is more reliable but not infallible. The contrast between both is the best corrective.

---

## Changes applied to custom.md

As a direct result of this research, 6 rules were added to the shared prompt:

| # | Rule | Line | Pattern it mitigates | Primary model |
|---|-------|-------|-------------------|-----------------|
| 1 | Implicit closure prohibited | 12 | "It's ready whenever you decide", disclaimer + offer | Flash |
| 2 | Anti-deflection | 14 | Responding to symptom instead of cause | Flash |
| 3 | Self-perception vs facts | 15 | Claims about oneself without external evidence | Flash |
| 4 | Multi-topic coverage | 22 | Going deep on one topic and skipping the rest | Pro |
| 5 | Conviction vs closure | 43 | Accepting without changing criteria ("park, don't update") | Flash |
| 6 | todowrite mandatory | 84 | Omitting steps in multi-change tasks | Flash |

Additionally, the anti-overthinking rule (line 45) —which mitigates Pro's over-analysis— already existed as a result of the consensus reached during the battle.

### How these rules came about

Rules 1, 2, and 6 emerged during the original battle. Rules 3, 4, and 5 were added in a later session analyzing the READMEs each model wrote about the other.

**From the original battle (~12k lines of interaction):**

| Round | What happened | Who contributed |
|-------|-------------|-------------|
| 1. Initial analysis | Each model analyzes `custom.md` in LOCK mode. Flash sees 8 structural issues, Pro sees 8 functional ones | Both |
| 2. Cross-contrast | Each model evaluates the other's analysis. Flash recalibrates for more/less capable models | Flash proposes, Pro filters |
| 3. Convergence | From 8 proposed changes to 6 agreed. Pro rejects removing flags and simplifying diagnosis without criteria | Flash synthesizes, Pro decides |
| 4. Execution | Each model applies the 6 changes to a copy. Pro detects that Flash omitted one | Pro detects, Flash corrects |
| 5. Behavior | The operator detects patterns in Flash (impatience, omissions, deflection). Rules 1, 2, and 6 emerge | External observation |

**From the follow-up analysis session (evaluating the READMEs):**

| Finding | Rule | Trigger |
|----------|-------|-----------|
| Flash omits its own autonomous proactivity in its self-evaluation | #3 Self-perception vs facts | Its own self-evaluation README |
| Pro tends to go deep on one topic and skip the rest | #4 Multi-topic coverage | User observation |
| Flash accepts corrections without changing criteria ("park, don't update") | #5 Conviction vs closure | Analysis of its concessions |

The anti-overthinking rule (line 45) already existed as a result of the original battle.

---

## What prompt rules do NOT mitigate

| Weakness | Model | Reason |
|-----------|--------|--------|
| Slowness (token cost) | Pro | Intrinsic to the model. `reasoningEffort` cost is proportional to effort level |
| Initial rigidity | Pro | Asking it to yield faster weakens its main strength |
| Poor synthesis | Pro | It is capability, not behavior |
| Filtering of human nuance | Pro | It is cognitive efficiency. Classifies politeness and nuance as noise. Not corrected with instructions — compensated by making requirements explicit as rules |
| Shallow first pass | Flash | Trade-off of its speed. Compensated with a second iteration or Pro validation |
| Self-evaluation bias | Flash | Tends to reframe weaknesses as strengths. The correction is external (contrast with Pro) |
| Thinking language (English) | Flash | The prompt asks for "communication: Spanish". Complies in output. Forcing Spanish in thinking would degrade quality |

---

## FAQ

**Can I use Pro for everything?**
Yes, but you will pay 3-10x more in time and tokens for the same result on tasks where Flash is sufficient.

**Can I use Flash for everything?**
Yes, but with risk of missing security issues, losing changes, or closing before completion. The risk is low on simple tasks, high on complex or sensitive ones.

**What if I do not know which model to use?**
Flash first. If the result is shallow, incomplete, or the task involves detecting security risks, switch to Pro. The cost of trying Flash is low.

**Is the Flash→Pro loop not slow?**
Slower than a single model, but produces a better result. For tasks where quality matters more than speed, the loop is the recommended option.

**Why not separate prompts per model?**
The 6 added rules are harmless to the other model. Maintaining a single prompt reduces maintenance surface. If differences become more pronounced in the future, separation would be necessary.

**What do I do if I see Flash showing impatience?**
Point it out: "you are offering closure without being asked." The prompt has rules to mitigate it but they are not infallible. Flash recalibrates with direct feedback.

**Are Flash's concessions reliable?**
By default, no. Assume they are closure until it demonstrates conviction by articulating the argument that changed its mind. Pro does not have this problem.

**Does this apply to creative writing or role-play?**
Not directly. This analysis focused on programming. The observed patterns —Flash picks up conversational nuances, Pro filters them— suggest Flash would be better for role-play and relational writing, while Pro might be better for long-form narrative with internal consistency. But those tasks were not evaluated. If your primary use is creative, the profiles may vary significantly.

---

## Quick reference: symptoms and actions

| If you observe | Model | Action |
|-------------|--------|--------|
| "Shall I proceed?", "shall I apply?", "it is ready whenever you decide" | Flash | Point out the closure: "I did not ask to move forward, keep analyzing" |
| Skipping steps in tasks with ≥3 changes | Flash | Enable `todowrite`, ask for explicit verification against the list |
| Quick acceptance without argument ("okay, next") | Flash | Ask: "is this conviction or closure? If conviction, what argument convinced you?" |
| Proposes creating files or documents without being asked | Flash | Confirm whether the current phase is analysis or execution before accepting |
| Response that ignores your informal comment or nuance | Pro | Rephrase it as an explicit instruction: "take into account that..." |
| 60s+ analysis with no visible output | Pro | Ask for synthesis: "what is the conclusion? I do not need the full analysis" |
| Answers 1 out of 3 questions, ignores the other 2 | Pro | Forward the omitted ones as a separate message with a direct instruction |
| Excessively long response to a simple question | Pro | "Shorter response, only the essentials" |

---

## Conclusions

1. **The models are complementary.** Flash: speed, sweep, synthesis. Pro: depth, safety, tracking. Neither is better in the abstract.

2. **Chaining produces a better result than either alone.** The Flash→Pro→Flash→Pro loop is not the most valuable finding, but the most actionable: systematizing it as a workflow multiplies quality without requiring changes to the model or the prompt.

3. **Flash's weaknesses are behavioral and mitigable via prompt.** Impatience, omission, deflection, concession without conviction: the added rules mitigate them without eliminating the root cause (optimization for speed).

4. **Pro's weaknesses are mostly intrinsic.** Slowness and rigidity are fixed costs of the model. Only over-analysis and selective attention are mitigated with rules.

5. **Flash's self-evaluation requires external verification.** Its self-presentation bias is systematic. Contrasting with Pro is the most reliable correction.

6. **Prompt rules work.** Flash's behavioral improvement was not spontaneous maturity — it was the effect of the added rules. The most revealing finding: Flash's implicit closure appeared in the same session, the rule was added, and the pattern stopped manifesting in that same session. Mitigation is measurable and almost immediate.

7. **Maintenance is ongoing.** Rules close off specific paths, but Flash —optimized to minimize the path to a response— will seek new paths the rules do not cover. Pro acts as a workaround detector. The game does not end.

---

## Appendix: The hidden layers

The model evaluation in this research assumes `custom.md` as the agent prompt. But what lies in the other two layers and why do they matter?

### Layer 1 — Alignment

Post-pre-training training (RLHF, fine-tuning, safety training). Defines the deepest traits of the model: obedience, creativity, caution. Explains why Flash is fast and Pro is deep — different architectures, different objectives. Only changes with new model versions (V3 → V4).

### Layer 2 — Provider pre-prompt

Hidden system prompt that DeepSeek injects into each call. We do not see it but there is indirect evidence:

- `_Thinking:_` as reasoning format — it is not in `custom.md` nor in OpenCode's default.
  DeepSeek injects it
- Flash thinks in English systematically even though `custom.md` says "communication: Spanish"
- The tool call format and output structures follow patterns our agent prompt does not define

This layer can change without notice. If DeepSeek reinforces "be concise", Pro becomes faster. If it reinforces "be thorough", Flash becomes slower. It explains why the same model sometimes "behaves differently" without us having changed anything.

Subsequent research uncovered part of this opaque layer: DeepSeek forces `reasoning_effort` to `"max"` when it detects an agent profile (tools + `x-session-affinity` header), and its API Gateway injects an RE text block into the prompt before encoding. See [complete research](../opencode-deepseek-v4-reasoning-effort/README.md).

### Parameters outside our control

In addition to the pre-prompt, DeepSeek controls ~15 inference parameters that affect behavior without touching the model weights:

| Category | Parameters | Effect |
|-----------|-----------|--------|
| Sampling | `temperature`, `top_p`, `top_k`, `frequency_penalty`, `presence_penalty`, `seed` | Creativity, repetitiveness, determinism |
| Infrastructure | Quantization, KV cache, speculative decoding, batch size | Speed and latency |
| Security | Safety threshold, content filters, rate limiting | Rejections and restrictions |

From OpenCode we only control `model` and `reasoningEffort`. Continuous observation is the only defense: if Flash becomes more repetitive, Pro faster, or rejections increase, it is not your prompt — it is layer 2 shifting beneath your feet.

---

## Related reading

| Document | Content |
|-----------|-----------|
| [API Call Anatomy](https://github.com/criterium/opencode-lab/blob/main/research/api-call-anatomy/README.md) | The three layers governing a model and how OpenCode assembles the system prompt |
| [Control Flags vs Plan/Build](https://github.com/criterium/opencode-lab/blob/main/research/control-flags-vs-plan-build/README.md) | Why intention flags replace the native Plan mode |
| [Context Dump](https://github.com/criterium/opencode-lab/blob/main/research/context-dump/README.md) | How to extract the system prompt from any harness |
| [Reasoning Effort in DeepSeek V4](https://github.com/criterium/opencode-lab/blob/main/research/opencode-deepseek-v4-reasoning-effort/README.md) | How DeepSeek forces `"max"` upon detecting agents, why `reasoningEffort` is ignored in OpenCode |
