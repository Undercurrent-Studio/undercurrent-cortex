---
name: plan-estimation
version: 0.1.0
description: |
  This skill should be used when the user asks to "estimate complexity", "how many waves", "how long will this take", "scope this out", "is this a big change", or before any non-trivial implementation planning. Surfaces historical plan data to calibrate expectations.
---

# Plan Estimation

**TL;DR**: Before estimating waves or complexity, check historical plans for similar work.

## Process

1. **Read recent plans**: Glob `.claude/plans/*.md` — read the last 20 by modification date
2. **Extract metadata**: For each plan, note:
   - Number of waves/phases
   - Domain (DB, pipeline, frontend, scoring, plugin, etc.)
   - Actual completion time if noted in journals
3. **Find similar work**: Match current task keywords against historical plans
4. **Surface comparison**: "Similar past tasks: [plan1] (N waves), [plan2] (M waves). Median: X waves."

## Calibration Rules

- Plugin/hook work: typically 1-2 waves per script, 15-30 min each
- Skill file creation/editing: 5-10 min per skill, can batch 3-4 per wave
- DB migrations + pipeline: typically 2-4 waves, 30-60 min each
- Frontend features: typically 3-5 waves depending on component count
- Full feature (DB + API + frontend): typically 4-8 waves

## When estimates seem off

If the plan has significantly more or fewer waves than historical precedent for similar work, flag it:
- "This plan has N waves but similar past work averaged M. Consider whether scope is right."

---
## See Also
- [plan-audit](../plan-audit/SKILL.md) — Estimation feeds into audit Gate 9 for scope and wave validation [downstream]
- [feature-design-flow](../feature-design-flow/SKILL.md) — Estimation calibrates complexity before design planning begins [workflow]
