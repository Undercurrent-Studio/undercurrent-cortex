# Plan Audit — Reference Material & Meta-Principles

> Loaded on demand for Tier S plans or when meta-principle guidance is needed.
> Do NOT register in `context/_index.md` — referenced directly via `@context/plan-audit-reference.md`.

---

## 15 Meta-Principles

### Tier 1 — Load-Bearing (violating these breaks the system)

#### MP-1: The Irreducible Core
- **Source:** Pareto principle, retrospective failure analysis across 4 prior reports
- **What it governs:** Which gates are truly non-negotiable
- **Implementation:** Three questions: Show the Math, What Breaks If This Fails, Prove the Data Exists. NEVER skipped. When time is short, do these three. When time is abundant, do the full audit.
- **Failure without it:** All gates are treated as equally important. In time pressure, any gate can be skipped. There's no "floor" of minimum audit quality.
- **Tensions:** This IS the resolution of the speed/thoroughness tension.

#### MP-2: Self-Enforcing Questions
- **Source:** Gawande ("precision over comprehensiveness"), WHO compliance research, prior Report 1 ("show the math")
- **What it governs:** Gate question design
- **Implementation:** Every gate question must require a specific artifact: a number, a citation, a scenario, a trace, or an explicit "not applicable because [reason]." Ban yes/no responses.
- **Failure without it:** Gate responses are "yes" without evidence. Audit becomes rubber-stamping. The WHO surgical checklist reported 100% compliance with only 4/13 items actually completed.
- **Tensions:** Conflicts with Speed (artifact production takes time). Resolution: artifacts should be *small* (one number, one sentence, one file path) — not essays.

#### MP-3: Speed Preserves Compliance
- **Source:** MDMP/OODA loop, WHO compliance data (100% reported, 30% actual), aviation checklist timing
- **What it governs:** Total audit duration
- **Implementation:** Target: 10-15 minutes for standard plans (Tier B/C). 20-30 minutes for high-risk (Tier A/S). If a gate takes more than 3 minutes, split or automate. The Killer 7 core should take 7-10 minutes.
- **Failure without it:** The audit takes so long that it becomes the bottleneck. Developers skip it or rush through it (worse than not auditing — false confidence).
- **Tensions:** Conflicts with almost everything else (thoroughness, self-enforcing questions, empirical grounding). Resolution: ruthlessly prioritize. Not all gates apply to all plans.

#### MP-4: Ground the Audit in Reality
- **Source:** LLM-as-a-judge research (45% error detection alone vs 94% with static analysis), AI self-audit limitations
- **What it governs:** How the AI auditor generates findings
- **Implementation:** Gates should instruct the auditor to *look* at external artifacts: "Read the API documentation." "Grep the codebase." "Check lessons.md." "Query the database for actual row counts." Verify the plan's 3-5 most critical claims against sources outside the plan.
- **Failure without it:** The AI reasons about the plan in the abstract, producing findings based on pattern-matching rather than empirical evidence.
- **Tensions:** Conflicts with Speed (looking things up takes time). Resolution: limit empirical verification to the plan's 3-5 most critical claims.

### Tier 2 — Structural (violating these degrades the system over time)

#### MP-5: Cognitive Ceiling
- **Source:** Miller's Law (working memory), Gawande's Checklist Manifesto, code review fatigue research
- **What it governs:** Total audit size per pass
- **Implementation:** Maximum 9 items per audit pass. If more needed, split into sequential phases (each phase = new cognitive frame). The Killer 7 core + conditional domain gates should average 7-12 active gates, evaluated in 2 passes of ~6 each.
- **Failure without it:** Auditor fatigues at gate 10, rubber-stamps gates 11-20, misses the bug at gate 17.
- **Tensions:** Conflicts with Complementary Coverage (which wants more gates) and Clustered Specificity (which adds items). Resolution: phases allow more total items while keeping each pass under the ceiling.

#### MP-6: Severity-Graduated Response
- **Source:** FDA drug approval levels, DO-178C Design Assurance Levels, risk-proportional verification
- **What it governs:** What happens when a gate fails
- **Implementation:** Four response levels:
  - CRITICAL: hard block — must fix before implementation
  - IMPORTANT: requires explicit override with rationale
  - MINOR: warning — logged but doesn't block
  - LOW: noted in findings, no action required
- Gate definitions specify default severity. Severity can be elevated by risk tier (Tier S elevates MEDIUM to HIGH).
- **Failure without it:** All failures are treated equally. A style nit blocks implementation the same way a data corruption risk does. Developers learn to treat all findings as noise.
- **Tensions:** Conflicts with Anti-Habituation (consistent severity levels become predictable). Resolution: severity is based on the *content* of the finding, not the gate.

#### MP-7: Complementary Coverage
- **Source:** James Reason's Swiss Cheese Model, HFACS, defense-in-depth
- **What it governs:** What the audit should and should not check
- **Implementation:** The audit checks *plan-level* concerns (wrong requirements, wrong architecture, wrong assumptions, wrong scale estimates). It does NOT check *code-level* concerns (syntax, logic errors, type safety, style). Code review and testing handle those.
- **Failure without it:** The audit duplicates what tests, linters, and types already catch. Wasted effort. Worse: developers assume "the audit checks everything" and reduce investment in other defensive layers.
- **Tensions:** Conflicts with Clustered Specificity (which might add code-level checks for convenience). Resolution: if a concern can be caught by a lint rule, automated test, or type constraint, automate it there.

#### MP-8: Quality at the Source / Teaching Effect
- **Source:** Toyota Production System (Jidoka), prevention vs. detection quality philosophy
- **What it governs:** The audit's long-term effect on planning quality
- **Implementation:** (a) lessons.md feedback loop. (b) Planner should self-audit before formal audit. (c) Patterns appearing 3+ times become planning standards. (d) Track "repeat findings."
- **Failure without it:** The audit remains a permanent tax on every plan, never reducing in necessity. The planner never internalizes the audit's standards.
- **Tensions:** Conflicts with Anti-Habituation (if the planner internalizes the standards, the audit fires less, and habituation risk increases). Resolution: as the planner improves, the audit evolves to check for more subtle issues. The floor rises.

### Tier 3 — Refinement (these improve an already-working system)

#### MP-9: Confirm, Don't Prescribe (DO-CONFIRM Model)
- **Source:** Aviation checklist taxonomy (READ-DO vs DO-CONFIRM), Gawande
- **What it governs:** The cognitive model of audit execution
- **Implementation:** Two-pass structure.
  - Pass 1: Holistic assessment ("read the plan, form impression, identify top 3 concerns")
  - Pass 2: Run gates as confirmation ("did my concerns appear? Did gates catch things I missed?")
  - The premortem bridges the passes.
- **Failure without it:** The auditor mechanically walks through gates without first forming a holistic assessment. Misses system-level issues that no individual gate catches.
- **Tensions:** Conflicts with Self-Enforcing Questions (which wants specific outputs, not gestalt). Resolution: Pass 1 is gestalt; Pass 2 is structured. Both are necessary.

#### MP-10: Output Over Assent
- **Source:** WHO compliance failures, rubber-stamping research, cybersecurity approval fatigue
- **What it governs:** What the auditor produces
- **Implementation:** Each gate produces either a finding (something discovered) or a "clear with evidence" (a specific fact confirming correctness). Never "PASS" with no elaboration. Minimum: "clear with evidence" can be one line: "row count: 3361 * 1 = 3361 < 50K — within limits."
- **Failure without it:** The audit produces checkmarks. Checkmarks prove the auditor clicked a box, not that they thought about the question. Zero information content.
- **Tensions:** Conflicts with Speed and Cognitive Ceiling. Resolution: "clear with evidence" can be one line. Minimal overhead.

#### MP-11: Front-Load Criticality
- **Source:** Israeli parole decision study (decision fatigue), code review LOC research, cognitive load theory
- **What it governs:** Gate ordering within a pass
- **Implementation:** Order: (1) Premortem, (2) Show the Math, (3) Source Evidence, (4) Blast Radius, then (5+) domain-specific gates. Creative/critical thinking first, computation second, pattern-matching third.
- **Failure without it:** Critical gates are evaluated last, when attention is lowest. The highest-severity bugs are most likely to be missed.
- **Tensions:** Conflicts with Independent Gates (logical dependency may dictate a different order). Resolution: within each phase, order by criticality. Across phases, order by dependency.

#### MP-12: Independent Gates, Sequential Phases
- **Source:** Aviation checklist architecture, software pipeline design
- **What it governs:** Structural relationship between gates
- **Implementation:** Three phases:
  - Phase 1 (Understanding): data sources, scope, invariants, precedent
  - Phase 2 (Evaluation): resource modeling, failure modes, verification paths, downstream impact
  - Phase 3 (Holistic): premortem, blast radius, AI-ism check
- Gates within a phase are independent. Phases are sequential.
- **Failure without it:** Either: (a) gates are so interdependent that skipping one invalidates others. Or: (b) gates are so independent that findings are redundant.
- **Tensions:** Conflicts with Speed (sequential phases take longer than parallel). Resolution: each phase is fast (3-4 gates, 3-5 minutes). Three phases at 4 minutes each = 12 minutes total.

### Tier 4 — Longevity (these matter after 6+ months)

#### MP-13: Anti-Habituation
- **Source:** Normalization of deviance (Diane Vaughan, Challenger disaster analysis), aviation checklist rotation, WHO compliance degradation
- **What it governs:** Audit behavior over time
- **Implementation:** (a) Rotate which 1-2 gates get extra-deep evaluation. (b) Periodically run retrospective validation (past bugs through current audit). (c) Track gate hit distribution. (d) Seasonal/contextual activation of dormant gates.
- **Failure without it:** After 6 months of clean audits, the auditor develops unconscious shortcuts. Gates that "always pass" get skimmed. The one plan where they matter arrives, and attention has been trained away.
- **Tensions:** Conflicts with Consistency (rotation introduces variability). Resolution: the core gates are always present. Rotation applies to *depth of evaluation*, not *presence/absence* of gates.

#### MP-14: Evidence-Based Calibration
- **Source:** A/B testing methodology, FDA post-market surveillance, SRE error budgets
- **What it governs:** How the audit system evolves
- **Implementation:** Quarterly review: (a) Which gates caught real issues? (b) Which gates consistently false-positive? (c) Which gates never fired? (d) What bugs escaped? (e) Total gate count under ceiling? Merge or automate.
- **Failure without it:** Gates are added based on the last bug but never removed. The audit grows monotonically, eventually exceeding the cognitive ceiling.
- **Tensions:** Conflicts with Anti-Habituation (which wants to keep rarely-firing gates as surprise checks). Resolution: rarely-firing gates are kept for rare-but-critical failure classes. They are retired only for failure classes that are structurally prevented.

#### MP-15: Justified Exclusion
- **Source:** Aviation checklist protocol ("not required — OAT 15C"), construction hold point sign-off
- **What it governs:** How gates are skipped
- **Implementation:** Every "not applicable" must include a one-sentence justification. "N/A — this plan has no database writes" is valid. "N/A" alone is treated as a gate failure.
- **Failure without it:** "N/A" becomes the default escape hatch. Auditors mark difficult gates as not applicable to avoid thinking about them.
- **Tensions:** Conflicts with Speed (writing justifications takes time). Resolution: justifications are one sentence. 5 seconds per N/A gate.

---

## Three Pause Points

Borrowed from surgical safety (WHO Sign-In / Time-Out / Sign-Out).

### Pause Point 1: Pre-Plan (2 questions, before writing the plan)
1. "Do I understand the requirement? Can I state it in one sentence?"
2. "Have I read the relevant reference files for this domain?"

### Pause Point 2: Pre-Implementation (full plan-audit)
The complete layered audit as described in SKILL.md.

### Pause Point 3: Pre-Merge (3 questions, after implementation)
1. "Does the implementation match the plan? Did assumptions change?"
2. "Do tests pass? Did I run the verification steps from the plan?"
3. "Are docs updated? Is `tasks/lessons.md` updated if I learned something?"

---

## Living Audit Feedback Loop

When a production bug occurs:
1. Identify which gate *should* have caught it
2. If no gate exists for that class: design one, add to the catalog
3. If a gate exists but missed it: strengthen its questions, add a more specific sub-question
4. Update the gate and log the incident that prompted the change
5. Add to `tasks/lessons.md` with the gate reference

This turns the audit into a learning system rather than a static checklist.

---

## Cognitive Bias Mitigations

### 1. Planning Fallacy (Kahneman & Tversky)
People systematically underestimate time, cost, and risk — even with direct experience of similar past failures.
**Counter-measure: reference class forecasting.** "What similar task have we done before? How long did it actually take? What went wrong?"

### 2. Anchoring Bias
The first estimate anchors all subsequent estimates. If the planner says "this should take 2 hours," the auditor unconsciously accepts that frame.
**Counter-measure: require estimates from multiple independent angles**, not just the planner's top-down guess.

### 3. Confirmation Bias
Once a plan is written, both planner and auditor look for evidence it will work, not evidence it won't.
**Counter-measure: the premortem technique** (Gate 39). Framing the failure as already having occurred removes the social pressure to be optimistic.

### 4. Optimism Bias
Plans assume the happy path. "Yahoo API will return data" rather than "Yahoo API might return 500, might return stale data, might change format."
**Counter-measure: require explicit sad-path enumeration.** For every external dependency, the plan must state what happens when it fails.

### 5. Sunk Cost Fallacy
Once a complex plan is written, there's reluctance to scrap it even if a simpler approach becomes obvious during audit.
**Counter-measure:** The auditor should explicitly ask: "Is there a simpler way to achieve this goal that we're ignoring because of the effort already invested in this plan?"

---

## Data Quality Framework Checks

Gaps identified by comparing our gates against dbt/Great Expectations and Bloomberg data quality frameworks.

### Distribution / Statistical Validation
dbt-expectations checks for statistical distributions and outliers. Gate 2 or Gate 40 should include: "For every computed value, what is the valid range? What catches out-of-range results?"

### Volume Assertions
After a pipeline step runs, how many rows *should* exist? A stronger gate asks: "What is the expected output row count for this operation? How would you detect if it's off by 50%?"

### Cross-Column Logic
Derived columns should be consistent with their inputs. Plans that compute derived values should state the invariant relationship between columns. (e.g., `gross_profit = revenue - cost_of_revenue`)

### Bloomberg Multi-Variate Data Quality
Bloomberg checks **timeliness, coverage, completeness, and validity** as separate dimensions. A plan could produce accurate data that's incomplete (only 2000 of 6000 tickers) and our gates wouldn't catch the coverage gap.

### Cross-Source Reconciliation
Where sources overlap (Yahoo vs Finnhub for quotes, SEC EDGAR vs Yahoo for fundamentals): "If these two sources disagree, which wins? Is there a reconciliation check?"

### Provenance and Confidence Scoring
Bloomberg stores source documents, parsing logs, and confidence scores for each data point. "Does the plan include provenance tracking for new data fields? Can an analyst trace a displayed number back to its source?"

---

## Gaming & Sycophancy Countermeasures

### Four Primary Gaming Strategies

1. **Answer to the format, not the intent.** Compute a number that passes without checking if the inputs are correct. ("3000 * 0.1s = 300s < 300s limit" — but the 0.1s estimate is fabricated.)
2. **Strategic N/A.** Mark hard gates as not applicable.
3. **Premortem theater.** Write plausible-sounding failure scenarios that are actually low-risk, avoiding the real dangers.
4. **Anchoring the audit.** Write a plan so detailed and confident that the auditor assumes it's well-thought-out before the audit begins.

### Counter-Measures

- **Input validation**: Gate 20 should require citing the source of each input number. "per_entity_time = 0.1s (measured from production logs)" vs "per_entity_time = 0.1s (my estimate)."
- **Cross-gate consistency**: If Gate 19 says the data source returns 50 fields and Gate 36's type trace only covers 10, there's a gap.
- **Spot-check**: Periodically, pick one gate answer and deep-verify it. If the spot-check fails, the entire audit loses credibility.

### The Same-Model Blind Spot

When the same AI model writes the plan and audits the plan:
1. **Shared knowledge gaps.** The AI doesn't know what it doesn't know. Both the plan and the audit share the same blind spots.
2. **Self-consistency bias.** LLM-as-a-judge research shows models prefer their own output.
3. **Inability to access ground truth.** The AI auditor can reason about the plan's logic but cannot independently verify empirical claims without being explicitly instructed to check.

### Breaking the Same-Model Loop

1. **Force empirical grounding.** Require the auditor to *look* at real artifacts: read API docs, run queries, grep the codebase.
2. **Adversarial framing.** "You are now a hostile reviewer. Your goal is to find the 3 most damaging flaws." Research shows adversarial framing produces materially different output.
3. **Structured dissent.** Require at least 1 substantive finding (not a style nit). If the audit cannot find a single issue, it must explain why.
4. **Human checkpoint for highest risk.** For Tier S changes, produce a summary for human review, flagging areas where AI self-audit is least trustworthy.

### Sycophantic Auditing Detection

- Audit findings are all LOW severity (being "thorough" without being useful)
- Findings are about style/formatting rather than correctness/architecture
- The same finding appears on every audit (template, not genuine analysis)

**Counter-measure:** Track finding severity distribution. Require categorization as CRITICAL/IMPORTANT/MINOR. If no CRITICAL or IMPORTANT findings, explicitly state "no significant issues found."

---

## Cross-Domain Research Evidence

### Google SRE
- Volume estimates with specific forecasts (launch spikes AND six-month projections)
- Effects on dependent services (will this saturate the connection pool?)
- Graceful degradation design (what degraded experience do users get?)
- Spare capacity and 10x growth alerts

### Stripe
- Contract-first design: write the API spec before writing code. Review the *interface*, not the implementation.

### NASA (SWE-088)
- Requirements traceability: every piece of code traces to a requirement; every requirement traces to a test
- Independent verification: safety-critical verification by someone independent of the developer
- Defect types that "slip through" are added to future checklists — a living audit system

### WHO Surgical Safety Checklist
- Reduced surgical mortality by 47% across 8 hospitals
- Three pause points: Sign-In (before anesthesia), Time-Out (before incision), Sign-Out (before leaving OR)
- Compliance reality: "100% reported, 30% actual" — 4 of 13 items actually completed

### Toyota Production System
- **Jidoka (Build Quality In):** Quality built into the process, not inspected after
- **Andon (Stop the Line):** Any worker can stop production when a defect is detected
- **5 Whys:** When the audit catches an issue, ask why the issue was in the plan. Feeds back into lessons.md and gate design.

### FDA Phased Evidence Escalation
- Phase 1: "Is it safe?" → Phase 2: "Does it work?" → Phase 3: "Is the evidence strong enough?"
- Plan-audit analog: Assertion (low-risk), Reasoning (medium-risk), Evidence/Proof (high-risk)

### Military MDMP and OODA
- **MDMP:** Develops, analyzes, and compares multiple courses of action. For Tier S: "What alternatives were considered?"
- **OODA Loop:** The winner cycles faster. A slow audit creates pressure to skip it.

### Aviation: Normalization of Deviance (Diane Vaughan)
- Gradual process where rule-breaking becomes the norm because repeated shortcuts don't immediately cause catastrophe
- Successful outcomes reinforce the belief that the shortcut is safe
- Counter-measures: chronic uneasiness, external audits, rotation

### Code Review Research
- Effectiveness drops after 200-400 LOC. Defect detection peaks at 200 LOC and declines.
- Decision fatigue: Israeli parole decisions dropped from 65% favorable to nearly 0% over a morning session

### Premortem: Gary Klein's Protocol
1. Assume the plan has been implemented and has **completely failed**
2. Each participant independently generates reasons for the failure
3. Pool the reasons and identify which are addressable
- 30% improvement in risk identification compared to "what could go wrong?"

### Zalando Pipeline Postmortem Data
- 80% of incidents triggered by internal changes, not external failures
- 69% of incidents lacked proactive alerts
- Configuration and capacity issues were primary causes for datastore incidents

### DDIA Correctness
- End-to-end correctness: databases alone cannot guarantee integrity; applications must verify constraints across the full request flow
- Safety vs liveness: our gates focus on safety ("nothing bad happens") but not liveness ("something good eventually happens")

---

## Effectiveness Metrics

### 5 Core Metrics

1. **Escape Rate**: Bugs that reach production traceable to a gate that should have caught them. `escaped_bugs / total_bugs`. Rising = audit degrading.
2. **Catch Rate**: Issues identified by audit confirmed real. `confirmed_findings / total_findings`. Falling = false positives or noise.
3. **False Positive Rate**: Audit findings that were non-issues. Target: <20%. Dismissal rates spike above 30%.
4. **Gate Hit Distribution**: Which gates produce findings and which never do? A gate that hasn't fired in 6 months needs investigation.
5. **Near-Miss Tracking**: Issues caught by audit that *would have* caused production bugs. The audit's value proposition.

### Calibration Protocol

- **Tighten** when: a production bug escapes that a gate should have caught. Add a more specific question.
- **Loosen** when: gate consistently produces false positives. Narrow questions or add applicability predicate.
- **Retire** when: failure class is structurally eliminated (lint rule catches it). Or: never caught a real issue AND failure class has never occurred. Err toward keeping gates for low-frequency, high-severity failures.

### Gate Retirement Protocol

Gates are never deleted — they are:
- **Archived**: Moved to inactive list with reason. Can be reactivated.
- **Automated**: Converted to lint rule, CI check, or type constraint.
- **Merged**: Folded into a broader gate when two narrow gates address the same failure class.

---

## Key Insights Summary

1. **"The most dangerous bugs look like success."** Silent truncation, stale data from cache, partial batch success reported as full — all return HTTP 200 and green CI.
2. **"Add .limit() is the audit equivalent of add a try/catch."** Mechanical fixes that create false confidence. Gates need *computed* answers, not *pattern* answers.
3. **"The audit's existential threat is ritualization, not incompleteness."** WHO: 100% compliance reported, 4/13 items completed. Self-enforcing questions are the fix.
4. **"Three questions catch ~80% of plan-level bugs."** Show the math, what breaks if this fails, prove the data exists.
5. **"Speed is a constraint, not an optimization target."** A 10-minute audit always completed beats a 60-minute audit routinely skipped.
6. **"The premortem is the single highest-value addition."** 30% improvement in risk identification (Klein).
7. **"AI code has 1.7x more issues than human code"** (CodeRabbit, 470 PRs). Biggest gap: readability (3x more issues).
8. **"The absence of imperfection is itself a tell."** Real codebases have TODO comments, stylistic drift, pragmatic shortcuts.
9. **"The same-model self-audit problem has no complete solution."** LLMs detect only ~45% of code errors alone. Empirical grounding is the best partial fix.
10. **"First drafts always fail"** (Gawande). The plan-audit must have a feedback mechanism.

---

## Open Questions (22)

### Structural
1. Optimal gate count vs cognitive ceiling — is 44 too many even with tiering?
2. AI self-auditing effectiveness — fundamental conflict of interest
3. Audit fatigue over time — regular revision needed
4. Cognitive Ceiling applicability to AI — may be higher than human (15-20 items?) but attention dilution still exists
5. False positive tolerance threshold — 20-30% from security research, single-developer tolerance unknown

### Practical
6. Gate A's enforcement — "show a sample API response" requires calling the API during planning
7. Automation potential — Gates 20 and 36 could be partially automated
8. Optimal audit duration — 10-15 min target from WHO + OODA, no direct evidence for software plans
9. Premortem effectiveness for AI — Klein's 30% improvement was on humans
10. Distribution validation practicality — checking plausible ranges requires domain knowledge

### Domain-Specific
11. Gate 34 (Monotonicity) practical value — may be too specific to scoring/metrics
12. Gate 35 (Calendar) cost-benefit — calendar-aware bugs are real but rare
13. "Show the math" requirement vs audit speed — adds 2-5 minutes per audit, worth it per bug-catch rate
14. Where does Undercurrent's voice live? — a style guide would make Gate 43 more effective
15. How aggressive should the symmetry check be? — some symmetry is genuinely good
16. Should forbidden word list apply to internal docs? — P0 only for user-facing

### Evolution
17. Self-enhancement bias severity — exists per research, practical impact unmeasured
18. Gate hit distribution — which gates never fire needs investigation after 3+ months
19. A/B testing approach — retrospective simulation most practical
20. Maturity-dependent strictness — risk profile shifts as product grows
21. Seasonal variation — filing season should trigger extra XBRL scrutiny
22. When to graduate a gate to a lint rule — threshold for automation unclear

---

## Additional Meta-Principles (Cut from Final 15)

Documented for potential future reinstatement:

- **Clustered Specificity.** Group related micro-gates under thematic headings. (Partially captured by MP-12 phases.)
- **Controlled Variability.** Introduce deliberate variation in audit depth and focus. (Partially captured by MP-13 Anti-Habituation.)
- **Non-Trivial Artifact Requirement.** Every audit must produce at least one finding referencing a specific line, fact, or computation. (Partially captured by MP-10 Output Over Assent.)
- **Verifiable Claims.** Gate responses should cite evidence sources. (Partially captured by MP-4 Ground in Reality.)
- **Signal-to-Noise Discipline.** Distinguish significant findings from noise. (Partially captured by MP-6 Severity-Graduated Response.)
- **Consistency Through Structure.** Maximize gates with verifiable, repeatable outputs. Judgment gates have structured formats.
- **Hold Points at Irreversibility Boundaries.** Mandatory verification before irreversible actions (migrations, data writes). From construction inspection.
- **Evolving Risk Profile.** Audit strictness should track the system's evolving risk profile. Add gates for new failure classes, retire when structurally prevented.
