---
name: review-decisions
description: Review decisions made 7-14 days ago to evaluate whether they held up, were revised, or caused downstream issues. Builds decision quality profile over time.
---

# Review Decisions

Read the decisions file at `.claude/undercurrent-decisions.local.md`.

## Steps

1. Parse all decision entries (format: `## YYYY-MM-DD - [title]` headers followed by metadata lines)
2. Filter to decisions made 7-14 days ago (old enough to evaluate, recent enough to remember)
3. For each decision in that window, present:
   - The original decision and its metadata (category, reversibility, confidence)
   - Ask: "Did this hold up? Was it revised? Did it cause downstream issues?"
4. Summarize: how many held up vs revised, which categories are most stable, confidence calibration (were high-confidence decisions actually correct?)

## If no decisions file exists
Say: "No decisions file found at `.claude/undercurrent-decisions.local.md`. Start logging decisions by including `[decision]` in your prompts."

## If no decisions in the 7-14 day window
Say: "No decisions in the 7-14 day review window. Recent decisions need more time to evaluate."
