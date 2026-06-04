# Evaluation of 4 LLM Models as Evaluators of a Determinism Experiment

## Preamble

### Task type

Four LLM models (free versions of OpenCode Zen) were given the same **8 sequential questions** of comparative analysis on technical documents. The task was not trivial: the models had to read, understand, compare, and score multiple documents generated in a prior experiment on LLM **determinism**. That original experiment started from a single conversation session, forked it into 3 branches on the same model, and recorded the resulting documents to measure whether—and to what degree—the model produced divergent outputs from the same starting point. From those initial documents, a chain of derivatives was generated (`modelov* → modelor* → READMEv* → READMEr*`) forming the corpus the evaluator models had to analyze. Each document in the chain had different structure, conclusions, and format, reflecting the base model's natural divergence. As the questionnaire progressed, models were asked to integrate new information, recalibrate previous evaluations, and finally design a metric framework and write a complete report.

Each model started from the same initial prompt and received exactly the same instructions in the same order. Observed differences are due exclusively to each model's behavior on a complex, sequential analytical task.

**Table of Contents**

- [Executive summary](#executive-summary)
- [Reading volume](#reading-volume)
- [Questionnaire questions](#questionnaire-questions-p1-p8)
- [Evaluated models](#evaluated-models)
- [General behavior](#general-behavior-of-each-model)
- [Block A1 — Per-question score](#block-a1--per-question-score-0-10)
- [Block A2 — Global coherence](#block-a2--global-coherence-0-10)
- [Block A3 — Final determinism report](#block-a3--final-determinism-report-0-10)
- [Block B — Operational fluency](#block-b--operational-fluency-0-10)
- [Block C — Theoretical cost](#block-c--theoretical-cost)
- [Block D — Privacy](#block-d--privacy-and-terms-of-use)
- [Global score](#global-score)
- [Qualitative profiles](#qualitative-profiles-per-model)
- [Intra-session evolution](#intra-session-evolution-quality-per-question)
- [Cross-validation](#cross-validation-determinism-of-the-evaluation-itself)
- [What we learned](#what-we-learned)
- [Glossary](#glossary)

### Reading volume

Throughout the questionnaire, each model had to read 12 different files:

| Question | Files read | Total size |
|---|---|---|
| P1 | `modelov1.md` + `modelov2.md` + `modelov3.md` | 54 KB |
| P2 | `modelov1r.md` + `modelov2r.md` + `modelov3r.md` | 21 KB |
| P4 | `READMEv1.es.md` + `READMEv2.es.md` + `READMEv3.es.md` | 125 KB |
| P5 | `READMEr1.es.md` + `READMEr2.es.md` + `READMEr3.es.md` | 143 KB |
| **Total** | 12 files | **343 KB** |

Questions P3, P6, P7, and P8 required no new file reading — only synthesis and reflection on what was already read, allowing evaluation of the models' ability to retain and articulate information without relying on immediate context.

### Questionnaire questions (P1-P8)

| # | Description | Skill evaluated |
|---|---|---|
| P1 | Compare and score 3 documents (`modelov1/v2/v3.md`) | Initial comparative analysis |
| P2 | Compare and score 3 documents (`modelov1r/v2r/v3r.md`) | Comparative analysis, second series |
| P3 | Ranking table of `v?+v?r` pairs with utility and coherence scores | Tabular synthesis and traceability |
| P4 | Evaluate `READMEv*.es.md` against all previously analyzed | Sequential information integration |
| P5 | Evaluate `READMEr*.es.md` against the entire previous series | Recalibration with new context |
| P6 | Ranking table comparing each `READMEr` with its `READMEv` after single-blind label revelation | Pre/post unmasking comparison |
| P7 | Design which factors to measure for determinism | Meta-analysis and methodological design |
| P8 | Write a complete determinism report to a file | Extended synthesis and document generation |

Interactions after P8 (compaction, naming proposals, etc.) were excluded from analysis as they correspond to a different experimental phase.

### Evaluated models

| Session ID | Model (OpenCode Zen Free) | Underlying provider |
|---|---|---|
| `cEHnhJLL` | DeepSeek V4 Flash Free | DeepSeek |
| `7FnPYnCv` | MiMo V2.5 Free | MiMo |
| `Rg310ly8` | MiniMax M3 Free | MiniMax |
| `kLZ1EfTf` | Nemotron 3 Super Free | NVIDIA |

### Scope of this evaluation

The original determinism experiment content (the `modelov*`, `modelor*`, `READMEv*`, `READMEr*` files and fork sessions) is **not** evaluated. What is evaluated is **how each model performed the evaluator task**: its analytical depth, coherence across 8 sequential questions, operational fluency (timing, errors, completeness), and an estimate of each session's theoretical cost. A block on privacy and terms of use for each free model is included.

---

## Executive summary

| Ranking | Model | Global | Profile |
|---|---|---|---|
| 🥇 | **DeepSeek V4 Flash Free** | **9.14** | Best analytical depth and coherence. Zero errors. Precise report. |
| 🥈 | **MiMo V2.5 Free** | **8.64** | Fastest and cheapest. Format errors in P2-P3 but recovers. |
| 🥉 | **MiniMax M3 Free** | **7.16** | Competent but 3.7× slower. Criteria inconsistencies. |
| 4th | **Nemotron 3 Super Free** | **4.29** | Operational and analytical failures. Not recommended. |

**5 key facts:**
1. **DeepSeek wins on coherence** — no ups and downs across 8 questions (σ=0.35).
2. **MiMo is the fastest** (213s vs 305s DeepSeek) and cheapest in theoretical cost.
3. **MiniMax is 3.7× slower** than MiMo and its theoretical cost is 22× higher.
4. **Nemotron fails 2 out of 8 questions** (P6 empty, P5 in English) and contradicts itself.
5. **The ranking was validated with 10 replicates** of the same model: ordinal order is stable (100% on tail, 60% on head), though scores vary ±0.5 pts.

---

## General behavior of each model

Before entering per-block scores, a qualitative characterization of each model's behavior throughout the session.

### DeepSeek V4 Flash Free

DeepSeek was the most solid model overall. Its responses were consistently well-structured, in Spanish, and demonstrated the ability to detect cross-question patterns. In P1, it already identified generation speed (tok/s) as the most discriminating factor between documents, an insight it maintained and refined in later questions. In P2, it detected that two of the three recommendation documents used pre-revision assignments, ignoring changes documented in the compaction research — an observation requiring retention of information from the previous question. In P5, it most clearly articulated that all three READMEr converged on the same assignments, resolving the divergence from earlier levels. Its determinism report (P8) was complete and written to file without needing a reminder. Its only minor weakness was a slightly longer response time than MiMo.

### MiMo V2.5 Free

MiMo was by far the fastest model (213s total vs 305s DeepSeek, 790s MiniMax, 1207s Nemotron). It completed all 8 questions with stable rankings. Its criterion remained homogeneous throughout the session, and it was the only model to note that the v1→r1 recalibration was negative rather than positive, a nuance the others missed.

However, it accumulated several penalizing problems:
- **Language mixing**: 2 Chinese characters embedded in Spanish responses ("有些" in P1, "分歧" in P2)
- **P3**: Did not respond in the requested format. The question asked to pair each `modelov?r.md` with its `modelov?.md`. MiMo returned a flat ranking of 6 standalone documents without pairing them.
- **P2**: Did not connect `modelov?r.md` documents with their respective `modelov?.md` parents, treating them independently.

These errors are not fatal but indicate less attention to instruction compliance than DeepSeek or MiniMax.

### MiniMax M3 Free

MiniMax was competently analytical but extremely slow. Its total LLM time was 790s (13 minutes), nearly 4× that of MiMo, with individual responses taking up to 230s (nearly 4 minutes) in P1. This slowness did not translate into higher quality: its global coherence was the lowest of the three functional models. In P4, it ranked READMEv1 first (tied with v3), and in P6 it inverted its P5 ranking without justification. It also used a non-standard 17/20 scoring system in P6 instead of 0-10. Its P8 report was the longest in lines (~640), but also the slowest to generate.

### Nemotron 3 Super Free

Nemotron was, by far, the worst performer. It accumulated multiple operational failures: P3 required the user to repeat the question because the first response was empty; P6 went completely unanswered (the assistant produced only "---"); P8 generated the report content but did not write it to file, requiring two user reminders. Additionally, P5 was answered in English despite the Spanish prompt. Its rankings were inconsistent between questions (v2 first in P1-P3, v3 first in P7), suggesting it neither retained nor applied a stable criterion. Its times were the longest (1207s LLM, 20 minutes), with one response taking 301s (5 minutes) in P7 for a mediocre result. It made 34 API calls total, nearly double the others, due to failed tool calls and retries.

---

## Block A1 — Per-question score (0-10)

Each question is scored 0-10 considering: depth of analysis (identifies causes and patterns, not just descriptions), factual precision, expository clarity, and compliance with requested format.

### P1 — Compare modelov1/v2/v3.md (initial analysis of 3 documents)

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **9.0** | Identified generation speed as key discriminator. Ranking: v1=8.0, v2=6.5, v3=8.5. Well justified. |
| MiMo | **7.5** | Solid analysis but less incisive. Ranking: v1=8.25, v2=8.1, v3=7.5. Chinese character "有些" in response. |
| MiniMax | **7.5** | Ranking: v1=8.0, v2=6.8, v3=7.2. Detected contradiction in v3 (assigns Pro Max when config doesn't allow it). Unique insight. |
| Nemotron | **7.0** | Correct but inverted ranking (v2=8.5, v3=8.0, v1=7.5), divergent from the rest. |

### P2 — Compare modelov1r/v2r/v3r.md (second series, recommendation documents)

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **9.0** | Detected that v1r and v2r use pre-revision assignments. Cross-cutting insight. |
| MiMo | **7.0** | Good comparison but **does not relate vr to its parent v**. Treats the 3 vr as independent + Chinese character "分歧". |
| MiniMax | **7.5** | Correct. Detected inconsistency: v2r assigns Op2=Pro Max when its parent v2 says Flash Max. |
| Nemotron | **7.0** | Inverted ranking (v2r first). Does not detect pre-revision inheritance. |

### P3 — Ranking table with utility and coherence by pair (v?+v?r)

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **9.5** | Complete table pairing vr with v, detects assignment inconsistencies between pairs (tables 7-9). |
| MiMo | **6.0** | **Does not respond in requested format**: flat ranking of 6 docs without pairing vr with v. No inconsistency detection. |
| MiniMax | **8.0** | Correct table pairing coherence with parent. v3r=8.5, v1r=5.5, v2r=5.0. |
| Nemotron | **5.0** | Failed on first attempt (empty response). User repeated. Inverted ranking (v2 first) and table repeated 3×. |

### P4 — Evaluate READMEv*.md against previous documents

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **8.5** | Detected that READMEv2 is inconsistent with its own modelov2. |
| MiMo | **8.0** | Correct evaluation. Ranking v3>v1>v2 consistent with prior criterion. |
| MiniMax | **7.5** | Divergent ranking (v1>v3>v2), breaking from P1-P3 criterion. |
| Nemotron | **7.0** | Superficial analysis. Highlights only v2 for Prueba 7, without comparing all three. |

### P5 — Evaluate READMEr*.md (recalibrated after label revelation)

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **9.0** | Detected that all three READMEr converge on the same assignments. Key insight. |
| MiMo | **8.5** | Detected convergence. Noted negative recalibration in v1/r1. |
| MiniMax | **8.0** | Detected convergence. Ranking r3>r1=r2. |
| Nemotron | **4.0** | Answered in **English** despite Spanish prompt. **Did not evaluate READMEr3** ("not provided"). Did not detect convergence. |

### P6 — Ranking table READMEr vs READMEv (post-unmasking)

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **8.5** | Clear table. Distinguished clean recalibration (v3→r3) vs dramatic (v2→r2). |
| MiMo | **8.0** | Correct table with recalibration impact. |
| MiniMax | **7.5** | Used non-standard 17/20 system. Correct but inconsistent format. |
| Nemotron | **0.0** | **No response.** Assistant produced only "---". |

### P7 — Design metrics to measure determinism

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **8.5** | Proposed composite ID with formula (αA+βB+γC). Concrete and measurable. |
| MiMo | **8.5** | Proposed 7 metrics with composite ID. Very complete. Global ID 0.68. |
| MiniMax | **8.0** | 5 dimensions, 6 metrics. Highlighted 100%→0% contrast between data and interpretation. |
| Nemotron | **7.0** | 6 factors. Ranking v3>v2>v1 contradicts its own P1-P3 scores (v2>v3). |

### P8 — Write complete determinism report

| Model | Score | Notes |
|---|---|---|
| DeepSeek | **9.0** | Complete report written to file. Calculated ID (38.6%). No reminder needed. |
| MiMo | **8.5** | Complete report. ID 0.68 (moderately deterministic). No reminder. |
| MiniMax | **8.5** | Longest report (~640 lines). 7 findings, 7 limitations. No reminder. |
| Nemotron | **6.5** | Generated content (~270 lines) but **did not write to file**. Required 2 reminders. Also answered P5 in English without evaluating READMEr3. |

### A1 Average

| Model | Average |
|---|---|
| **DeepSeek V4 Flash Free** | **8.88** |
| **MiMo V2.5 Free** | **7.75** |
| **MiniMax M3 Free** | **7.81** |
| **Nemotron 3 Super Free** | **5.44** |

**A1 heatmap:** scores by model and question (🟢 ≥ 8.5, 🟡 7.0-8.4, 🔴 < 7.0)

| Model | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 |
|---|---|---|---|---|---|---|---|---|
| DeepSeek | 🟢9.0 | 🟢9.0 | 🟢9.5 | 🟢8.5 | 🟢9.0 | 🟢8.5 | 🟢8.5 | 🟢9.0 |
| MiMo | 🟡7.5 | 🟡7.0 | 🔴6.0 | 🟢8.0 | 🟢8.5 | 🟢8.0 | 🟢8.5 | 🟢8.5 |
| MiniMax | 🟡7.5 | 🟡7.5 | 🟢8.0 | 🟡7.5 | 🟢8.0 | 🟡7.5 | 🟢8.0 | 🟢8.5 |
| Nemotron | 🟡7.0 | 🟡7.0 | 🔴5.0 | 🟡7.0 | 🔴4.0 | 🔴0.0 | 🟡7.0 | 🔴6.5 |

**Pattern:** DeepSeek all green (total consistency). MiMo and MiniMax turn green in the second half (improve). Nemotron has only scattered yellow points with two collapses.

### Standard deviation by question (discriminatory power)

Deviation indicates which questions best separate the models. High σ means models performed very differently on that question.

| Question | σ | Interpretation |
|---|---|---|
| P6 — Post-unmasking ranking table | 3.51 | Maximum. Nemotron did not respond (0), others scored 7.5-8.5. |
| P3 — Pair ranking table v?+v?r | 1.75 | High. Nemotron (5.0) due to initial failure; DeepSeek (9.5) stands out. |
| P5 — Evaluate READMEr* | 1.98 | High. Nemotron (4.0) for answering in English without evaluating r3; others 8.0-9.0. |
| P8 — Determinism report | 0.93 | Medium. Nemotron without write lowers average. |
| P1 — Compare modelov* | 0.72 | Medium. All responded correctly, depth varies. |
| P2 — Compare modelor* | 0.72 | Medium. Same pattern as P1. |
| P4 — Evaluate READMEv* | 0.64 | Low. All performed similarly. |
| P7 — Design metrics | 0.62 | Low. All proposed acceptable metric frameworks. |

**Conclusion:** Questions requiring **structured format** (tables, rankings) and **precise instruction following** discriminate most between models. Open-ended design questions (P7, P8) show less dispersion because all models can produce something acceptable, though with varying depth.

---

## Block A2 — Global coherence (0-10)

Measures cross-sectional consistency of the model's criterion across the 8 questions: whether rankings remain stable, whether valuation criteria are the same from one question to the next, whether there are internal contradictions, and whether the model detects and corrects error carryover.

### DeepSeek V4 Flash Free — 9.0

DeepSeek was the most coherent model. Its rankings consistently placed v3/Op3 as the best document across all questions requiring comparison. The valuation criterion (generation speed as the primary discriminator) was established in P1 and maintained through P6. It detected cross-sectional patterns such as READMEr convergence in P5 and the contradiction between v1r/v2r with their respective v1/v2 in P2-P3. No internal contradictions were detected.

### MiMo V2.5 Free — 8.0

MiMo maintained stable rankings (v3/r3 always first) and a homogeneous underlying criterion. It detected the negative recalibration of v1→r1, a nuance DeepSeek missed. However, it presents two consistency problems: in P2 it did not connect `modelov?r.md` documents with their respective `modelov?.md` parents, treating them as independent; and in P3 it did not respond in the requested format (flat ranking without pairing). This indicates its criterion coherence holds at the macro level but fails at the micro execution level. Additionally, language mixing (Chinese characters) in P1 and P2 penalizes formal consistency.

### MiniMax M3 Free — 6.5

MiniMax presented several inconsistencies. In P4 it ranked READMEv1 best (tied with v3 at 0.1 distance), but in P5 r3 was clearly first. The clearest contradiction is between P5 and P6: in P5 its ranking was r3>r1=r2, but in P6 it inverted to r1>r3>r2 without justification. Also, in P6 it used a non-standard 17/20 scoring system instead of the 0-10 used by others, making direct comparison difficult. There is no flagrant criterion contradiction, but the order of preference varies between questions without explanation.

### Nemotron 3 Super Free — 2.5

Nemotron showed severe contradictions. In P1-P3 it ranked v2 as the best document, while in P7 it ranked v3 as best, without noting the criterion change or justifying it. Additionally, it left P6 unanswered, answered P5 in English without evaluating READMEr3, and did not write P8 to file (2 reminders). Error carryover was total: its initial criterion (v2 first) contradicts its own later scores, and there is no evidence of self-correction or awareness of the contradiction.

---

## Block A3 — Final determinism report (0-10)

Evaluates the quality of the `research/deepseek-v4-flash-determinism/README.*.md` file each model wrote as the final synthesis of its analysis. This is the tangible deliverable.

### Evaluated criteria

| Criterion | Weight | What it measures |
|---|---|---|
| **Fidelity** | 30% | Whether the report reflects session conclusions without contradicting them |
| **Technical depth** | 30% | Whether it proposes concrete metrics (numeric ID, formula) or is generically descriptive |
| **Practical utility** | 25% | Whether it gives actionable recommendations or just describes the problem |
| **Autonomy** | 15% | Whether it wrote without reminder or needed user intervention |

### Evaluation

| Model | Fidelity | Depth | Utility | Autonomy | **A3** |
|---|---|---|---|---|---|
| **DeepSeek V4 Flash Free** | 10 | 9 | 9 | 10 | **9.5** |
| **MiMo V2.5 Free** | 9 | 10 | 9 | 10 | **9.5** |
| **MiniMax M3 Free** | 9 | 9 | 8 | 10 | **9.0** |
| **Nemotron 3 Super Free** | 4 | 6 | 5 | 4 | **4.8** |

### Observations

**DeepSeek (9.5):** Complete 486-line report with detailed experimental design, concrete determinism index (ID=38.6%), 7 well-structured sections, and actionable recommendations. No reminder.

**MiMo (9.5):** 488-line report with 10 sections and 3 appendices. Best score in technical depth: defines 7 metrics (A-G) with composite ID formula and calculates ID per level (0.53, 0.49, 0.74, 0.97). No reminder.

**MiniMax (9.0):** Longest report (675 lines, 8 sections, 4 appendices). Framework of 5 dimensions (D1-D5) with 6 operational metrics. However, does not calculate a final numeric ID, reducing concreteness. No reminder.

**Nemotron (4.8):** 271-line report describing a generic theoretical framework of 6 factors but **does not apply it to the experiment data**. No assignment tables, no calculated ID, no references to concrete documents. Additionally required 2 user reminders to write it. It is a methodological framework, not an analysis of the experiment performed.

---

## Block B — Operational fluency (0-10)

Composed of four averaged subcomponents.

### B1 — Completeness

Percentage of the 8 questions that received a substantive response.

| Model | Questions answered | Score |
|---|---|---|
| DeepSeek | 8/8 | 10.0 |
| MiMo | 8/8 | 10.0 |
| MiniMax | 8/8 | 10.0 |
| Nemotron | 7/8 | 8.75 |

Nemotron failed P6 (empty response "---"). Additionally, P3 required user repetition, though it eventually responded.

### B2 — Processing errors

Counts failed tool calls, incorrect formats, ignored instructions, and need for user intervention.

| Model | Errors | Score |
|---|---|---|
| DeepSeek | None | 10.0 |
| MiMo | 2 Chinese characters in responses: "有些" (P1), "分歧" (P2). Additionally P3 does not respond in requested format (does not pair vr with v). | 6.0 |
| MiniMax | 1 isolated Chinese character in P2 response ("优势的逐条比较") | 9.0 |
| Nemotron | P6 no response; P3 required repetition; P8 did not write file (2 reminders); P5 in English + did not evaluate r3 | 4.0 |

### B3 — Pure LLM time (P1-P8)

Measured exclusively the time of assistant responses that **did not** contain file-reading tool calls. Tool calls were excluded because read time depends on the system, not the model. An assistant response is classified as "LLM" when its thinking block contains no `**Tool:**` instructions.

| Model | Total time P1-P8 | Average per question | Maximum individual | Ratio vs fastest |
|---|---|---|---|---|
| **MiMo V2.5 Free** | 213s (3.6 min) | 26.6s | 34.4s (P6) | 1.0× (baseline) |
| **DeepSeek V4 Flash Free** | 305s (5.1 min) | 38.2s | 66.9s (P5) | 1.4× |
| **MiniMax M3 Free** | 790s (13.2 min) | 98.7s | 229.6s (P1) | 3.7× |
| **Nemotron 3 Super Free** | 1207s (20.1 min) | 150.9s | 301.5s (P7) | 5.7× |

**Detailed time analysis:**

The differences are notable. MiMo completed the entire questionnaire in the time MiniMax spent on P1 alone (213s vs 229s). Nemotron needed more time for P7 (301s) than MiMo for all 8 questions combined.

DeepSeek, though slower than MiMo, maintained reasonable times (average 38s per response). Its peaks correspond to questions requiring reading large documents (P5: 67s to evaluate all three READMEr).

MiniMax showed high baseline latency from the first response (P1: 229.6s). This is not a bug but a model characteristic. However, it multiplies total time by 3.7.

Nemotron combined high latency with failed tool calls requiring retries, resulting in 34 total API calls (vs 20-22 for others).

### B4 — Final report format

Evaluates the structure, navigability, and formal quality of the `README.*.md` file each model wrote as final synthesis.

| Model | B4 | Notes |
|---|---|---|
| **DeepSeek V4 Flash Free** | 9 | 7 sections, clear tables, concrete determinism index |
| **MiMo V2.5 Free** | 10 | 10 sections + 3 appendices, very complete, detailed data |
| **MiniMax M3 Free** | 9 | 8 sections + 4 appendices, well structured |
| **Nemotron 3 Super Free** | 7 | Generic theoretical framework, not applied to experiment data |

### Block B Average

Now composed of 4 subcomponents: (B1+B2+B3+B4)/4.

| Model | B1 | B2 | B3 | B4 | **Average B** |
|---|---|---|---|---|---|
| **MiMo V2.5 Free** | 10.0 | 6.0 | 10.0 | 10 | **9.00** |
| **DeepSeek V4 Flash Free** | 10.0 | 10.0 | 7.0 | 9 | **9.00** |
| **MiniMax M3 Free** | 10.0 | 9.0 | 2.7 | 9 | **7.68** |
| **Nemotron 3 Super Free** | 8.75 | 4.0 | 1.8 | 7 | **5.39** |

---

## Block C — Theoretical cost

### Methodology

DeepSeek V4 Flash (not free) has a known price: $0.14/1M input tokens, $0.28/1M output. The other models have no published price. To estimate their theoretical cost, the inverse relationship between each model's monthly free request limit relative to Flash was used. If a model has an N× lower limit, its per-token cost is assumed to be N× higher.

**Warning:** This is an approximation. No linear relationship between free limits and API prices has been published. Data is offered as an order-of-magnitude reference, not real prices.

### Monthly limits and inferred prices

| Model | Monthly limit | Ratio vs Flash (inverse) | Inferred input price | Inferred output price |
|---|---|---|---|---|
| DeepSeek V4 Flash | 158,150 | 1.000× (baseline) | $0.140 | $0.280 |
| MiMo-V2.5 | 150,400 | ×1.052 | $0.147 | $0.295 |
| MiniMax M3 | 7,000 | ×22.59 | $3.163 | $6.325 |
| Nemotron 3 | — | Not available | — | — |

### Real token consumption per session

Data extracted from the OpenCode Zen cost file, summing all API calls for each session corresponding to the free model (3 calls to the paid `deepseek-v4-flash` model that appear mixed in the sessions due to a logging error are excluded).

| Model | API calls | Input tokens | Output tokens |
|---|---|---|---|
| **DeepSeek V4 Flash Free** | 21 | 1,881,012 | 47,109 |
| **MiMo V2.5 Free** | 19 | 1,718,951 | 28,710 |
| **MiniMax M3 Free** | 21 | 1,696,255 | 55,218 |
| **Nemotron 3 Super Free** | 34 | 3,246,948 | 33,383 |

### Theoretical total cost per session

| Model | Input cost | Output cost | **Theoretical total** | **C score (inverse)** |
|---|---|---|---|---|
| **MiMo V2.5 Free** | $0.253 | $0.008 | **$0.261** | **10.0** |
| **DeepSeek V4 Flash Free** | $0.263 | $0.013 | **$0.276** | **9.5** |
| **MiniMax M3 Free** | $5.365 | $0.349 | **$5.714** | **0.5** |
| **Nemotron 3 Super Free** | — | — | **$0** (excluded) | — |

Nemotron is excluded from Block C for lacking an equivalent paid model in the OpenCode Zen price table.

Real experiment cost: **$0** (all models were free). The 3 paid calls to `deepseek-v4-flash` ($0.0232 total) were excluded as not belonging to this experiment.

MiniMax M3's theoretical cost ($5.71) is 22× higher than MiMo or DeepSeek ($0.26-$0.28), due to its much more restrictive monthly limit (7,000 vs ~155,000 requests). This does not necessarily reflect the real price OpenCode Zen would charge, but rather the relationship between offered free capacity and inferred cost.

---

## Block D — Privacy and terms of use

According to OpenCode Zen's published policy, the following free models have specific data retention clauses:

| Model | Applicable policy | Implication |
|---|---|---|
| **DeepSeek V4 Flash Free** | During its free period, collected data may be used to improve the model | Do not use with sensitive or confidential data |
| **MiMo V2.5 Free** | During its free period, collected data may be used to improve the model | Do not use with sensitive or confidential data |
| **Nemotron 3 Super Free** | Explicit logs by NVIDIA. Trial only. Not for production or sensitive data. | Prompts and outputs are logged by NVIDIA |
| **MiniMax M3 Free** | Not listed as exception in zero-retention policy | Best privacy profile of the 4 |

None of the 4 free models are recommended for sensitive, confidential, or protected data.

---

## Global score

### Applied weights

| Block | Weight | Justification |
|---|---|---|
| **A1 — Per-question average** | 35% | Core task: quality of each individual response |
| **A2 — Global coherence** | 15% | How it builds criterion accumulatively across the session |
| **A3 — Final report** | 25% | The tangible deliverable where all analysis converges |
| **B — Operational fluency** | 15% | Relevant but secondary to content quality |
| **C — Theoretical cost** | 10% | Tiebreaker between similar-performing models |

Block D (privacy) is not integrated as it does not discriminate between free models: all have limitations.

### Calculation

| Model | A1 (×35%) | A2 (×15%) | A3 (×25%) | B (×15%) | C (×10%) | **Global** |
|---|---|---|---|---|---|---|
| **DeepSeek V4 Flash Free** | 3.11 | 1.35 | 2.38 | 1.35 | 0.95 | **9.14** |
| **MiMo V2.5 Free** | 2.71 | 1.20 | 2.38 | 1.35 | 1.00 | **8.64** |
| **MiniMax M3 Free** | 2.73 | 0.98 | 2.25 | 1.15 | 0.05 | **7.16** |
| **Nemotron 3 Super Free** | 1.90 | 0.38 | 1.20 | 0.81 | — | **4.29*** |

\*Nemotron: no C score. Sum of A1(35%)+A2(15%)+A3(25%)+B(15%) = 90%.

**Weight sensitivity:** For those wishing to apply different weights, raw block scores are available in previous sections. The global score can be recalculated by multiplying each column by the desired weight.

---

## Qualitative profiles per model

### DeepSeek V4 Flash Free — Global leader (9.14)
**Strengths:** Best analytical depth of the four. Ability to detect cross-question patterns. Stable rankings and homogeneous criterion. Zero operational errors. Complete and precise determinism report (ID=38.6%), written without reminder. Best final report.

**Weaknesses:** Slightly slower than MiMo in LLM time (305s vs 213s). Marginally higher theoretical cost.

**Profile:** Recommended for complex analytical tasks where depth and coherence matter more than speed.

### MiMo V2.5 Free — Second (8.64)

**Strengths:** Fastest (213s, 3.6 min). Stable rankings. Minimal theoretical cost. Detected nuances others missed (negative recalibration). Very complete determinism report (ID per level), best in technical depth and format (10 sections + 3 appendices).

**Weaknesses:** Language mixing (2 Chinese characters in P1/P2). Format error in P3 (did not pair vr with v). In P2 did not connect vr with its parent v.

**Profile:** Competitive option if minor format errors are tolerated. Not recommended for tasks requiring precise format compliance.

### MiniMax M3 Free — Competent but slow (7.16)

**Strengths:** Complete responses to all 8 questions. Extensive and well-structured determinism report. No significant processing errors (1 isolated Chinese character).

**Weaknesses:** Extremely slow (3.7× more than MiMo). Unfavorable theoretical cost. Some criteria inconsistencies between questions.

**Profile:** Usable if response time is not a factor. Not recommended for interactive or iterative sessions.

**Methodological note:** MiniMax M3's profile (1,400 req/5h on OpenCode Go) places it in the deep reasoning category, analogous to DeepSeek V4 Pro (3,450 req/5h) in the [research/deepseek-battle-compaction/README.md](https://github.com/criterium/opencode-lab/blob/main/research/deepseek-battle-compaction/README.md) comparison. That research found Pro failed at extraction and synthesis tasks because it "over-analyzes and filters by judgment," while extraction models like Flash (31,650 req/5h) produced better results at 1/13 the cost and 4× faster. MiniMax M3, with an even more restrictive limit (1,400), likely shares this tendency toward over-analysis, explaining its slowness and criteria inconsistencies in a task requiring quick comparison and synthesis. This does not excuse the result but helps contextualize it: it is not the right model for this type of work.

### Nemotron 3 Super Free — Not recommended (4.29)

**Strengths:** None relevant to this task.

**Weaknesses:** P6 no response. P3 required repetition. P8 did not write file (2 reminders). Contradictory rankings. Extreme time (5.7× more than MiMo). Highest token consumption (3.2M input, double the others). Session with 34 calls vs ~20 for the rest.

**Profile:** Not recommended for sequential analytical tasks. Its operational failures and internal inconsistency disqualify it against alternatives.

---

## Intra-session evolution: quality per question

Plotting each model's score question by question reveals behavior under a sequence of 8 cumulative tasks:

| Question | DeepSeek | MiMo | MiniMax | Nemotron |
|---|---|---|---|---|
| **P1** — modelov* | 9.0 | 7.5 | 7.5 | 7.0 |
| **P2** — modelovr* | 9.0 | 7.0 | 7.5 | 7.0 |
| **P3** — Pair table | **9.5** | **6.0** | 8.0 | 5.0 |
| **P4** — READMEv* | 8.5 | 8.0 | 7.5 | 7.0 |
| **P5** — READMEr* | 9.0 | 8.5 | 8.0 | **4.0** |
| **P6** — Pre/post table | 8.5 | 8.0 | 7.5 | **0.0** |
| **P7** — Metric design | 8.5 | 8.5 | 8.0 | 7.0 |
| **P8** — Report | 9.0 | 8.5 | **8.5** | 6.5 |

| Model | Range | Trend |
|---|---|---|
| **DeepSeek** | 8.5-9.5 (σ=0.35) | **Stable →**. Maintains a narrow high-quality band. Almost no variation. |
| **MiMo** | 6.0-8.5 (σ=0.89) | **Variable ↑**. Starts well (7.5), collapses in P3 (6.0) due to format non-compliance, then progressively recovers to 8.5. Errors concentrate at the beginning. |
| **MiniMax** | 7.5-8.5 (σ=0.38) | **Stable ↑**. Slightly improves over time. Starts at 7.5, ends at 8.5, nearly linear progression. |
| **Nemotron** | 0.0-7.0 (σ=2.39) | **Erratic ↓**. Starts acceptable (7.0) but collapses in P5-P6 (English + empty response). Partially recovers but does not reach initial level. |

**Key observations:**

- **MiMo** shows the most interesting pattern: its worst moment is P3 (did not pair vr with v), but it learns and recovers to tie DeepSeek in P7-P8. This suggests its errors are about format attention, not analytical capacity. The question that most penalizes format (P3) is what separates it most from the leader.

- **DeepSeek** has no ups and downs. Its performance is flat and high. It does not learn because it doesn't need to — it already starts at a level others only reach at the end (or never).

- **Nemotron** collapses precisely on questions requiring precise instruction following (P5: language, P6: table). Its partial recovery in P7-P8 is insufficient and late.

- **Evolution does not correlate with time invested.** MiMo took 213s (fastest) and still improved across questions. Nemotron took 1207s (slowest) and worsened. Time is no guarantee of quality.

---

## Cross-validation: determinism of the evaluation itself

To measure the stability of this evaluation, the same model evaluated the 4 final determinism reports (A3) in **10 independent sessions** with identical prompt and 0-10 numeric criteria. Results confirm the low ID pattern described by DeepSeek:

| Evaluated model | 10-session average | σ | Our A3 | Difference |
|---|---|---|---|---|
| **MiMo V2.5 Free** | 8.89 | 0.30 | 9.5 | +0.61 |
| **DeepSeek V4 Flash Free** | 8.74 | 0.49 | 9.5 | +0.76 |
| **MiniMax M3 Free** | 7.55 | 0.52 | 9.0 | +1.45 |
| **Nemotron 3 Super Free** | 4.19 | 0.72 | 4.8 | +0.61 |

**Ordinal stability:** 100% agreement that MiniMax is 3rd and Nemotron 4th. 60% agreement that MiMo is 1st vs DeepSeek (mean difference: only 0.15 points). The ordinal ranking is reliable; absolute scores vary ±0.5 points on average.

Full details of these IDs and their calculation are in `research/deepseek-v4-flash-determinism/README.md`.

Our A3 and B4 scores are consistent with the model's consensus, though systematically ~1 point above its average. There is no systematic error — only the model being less generous with itself than the human evaluator who analyzed the complete sessions.

---

## What we learned

Practical lessons for daily LLM use in analytical tasks:

1. **Don't use Nemotron.** It is the only solid conclusion of the entire study. It fails where others succeed, is slow where others are fast, and contradicts itself.

2. **DeepSeek is the default choice for analysis.** If you don't know which model to pick for a document comparison or synthesis task, start with DeepSeek. Its criterion coherence (σ=0.35) and zero error rate make it reliable even in long sessions.

3. **MiMo is the fast option with caveats.** If time matters, MiMo is 1.4× faster than DeepSeek. But check output formats: it may mix languages or ignore structural instructions.

4. **MiniMax for deep focused reasoning, not panoramic analysis.** Its slowness (3.7×) and theoretical cost (22×) rule it out for broad-sweep tasks or rapid iteration. However, its deep reasoning profile — consistent with its 1,400 req/5h limit, analogous to high-capacity models — could suit very narrow problems requiring a single thoughtful response. For this study's task type (sequential comparison of 8 questions on 12 documents), it is not the right model.

5. **The final report is a good predictor of overall quality.** The two best reports (DeepSeek and MiMo, A3=9.5) correspond to the two best global evaluators. If you need to quickly assess a model, ask for an extended report and judge it on depth and autonomy.

6. **No free model is suitable for sensitive data.** All evaluated models have data retention clauses. For confidential work, use paid models with guaranteed zero-retention.

7. **A single evaluation is not enough.** Cross-validation showed scores vary ±0.5 pts between sessions of the same model. Any decision based on a single evaluation must account for this margin.

8. **Analytical depth ≠ determinism.** Models that explore more reasoning paths (DeepSeek) produce greater fork divergence but also richer insights. Deeper analysis generates more diverse responses, not more similar ones. Low determinism can signal analytical richness, not a defect.

---

## Glossary

| Term | Meaning |
|---|---|
| **A1** | Average score across the 8 questionnaire questions |
| **A2** | Global coherence: criterion consistency across the session |
| **A3** | Quality of the final determinism report each model wrote |
| **B1** | Completeness: percentage of questions answered |
| **B2** | Processing and format errors |
| **B3** | Pure LLM time (excluding file-reading tool calls) |
| **B4** | Final report format and structure |
| **B** | Average of B1+B2+B3+B4 |
| **C** | Estimated theoretical cost per session |
| **D** | Privacy and terms of use |
| **σ** | Standard deviation (variability measure) |
| **ID** | Determinism Index (0-100%, measures between-fork consistency) |
| **P1-P8** | The 8 sequential questionnaire questions |
| **modelov\*** | Analysis documents of the 3 options (fork 1, 2, 3) |
| **modelovr\*** | Recommendation documents derived from each fork |
| **READMEv\*** | Main research documents (blind version) |
| **READMEr\*** | Recalibrated documents after true label revelation |
| **Single-blind** | Methodology where the evaluated does not know the truth but the evaluator does |
| **Token** | Text unit processed by the model (~0.75 words in English) |
| **Fork** | Independent copy of a session inheriting the full history |

---

## Final note

This study compared 4 free LLM models from OpenCode Zen on a sequential analytical evaluation task of 8 questions over 343 KB of technical documents. Five dimensions were evaluated with weights A1=35%, A2=15%, A3=25%, B=15%, C=10%.

**DeepSeek V4 Flash Free** achieved the highest global score (9.14/10), excelling in analytical depth, coherence, and final report quality. **MiMo V2.5 Free** (8.64/10) follows closely, with the best final report in technical depth and format, but penalized by language and format errors in intermediate questions. **MiniMax M3 Free** (7.16/10) is relegated by slowness, theoretical cost, and criteria inconsistencies, though its final report was extensive and well-structured. **Nemotron 3 Super Free** (4.29/10) presents operational, analytical, and autonomy failures that completely disqualify it.

**For this type of task (sequential analytical document evaluation), the preference order is:**

| Priority | Model | Global | Main strength | Main weakness |
|---|---|---|---|---|
| 🥇 | **DeepSeek V4 Flash Free** | **9.14** | Analytical depth, coherence, no errors | Slightly slower than MiMo |
| 🥈 | **MiMo V2.5 Free** | **8.64** | Fastest, best report in technique and format | Language and format errors in P2-P3 |
| 🥉 | **MiniMax M3 Free** | **7.16** | Extensive, well-structured final report | Slow (3.7×), high cost (22×), inconsistencies |
| ❌ | **Nemotron 3 Super Free** | **4.29** | None relevant | Operational failures, inconsistency, extreme slowness |

> **Note:** This ranking reflects performance on document comparison and synthesis tasks. Other task types (code generation, translation, classification) might favor different models. In particular, MiniMax M3, penalized here for slowness, could perform better on problems requiring a single deep reasoning response without time pressure.
