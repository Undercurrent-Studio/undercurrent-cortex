---
name: code-review
description: Launch a structured 3-pass code review — bug/logic, security, and project conventions analysis with confidence scoring
---

Launch the `code-reviewer` agent to perform a structured 3-pass code review.

The agent will:
1. Load project context (CLAUDE.md, documentation.md, tasks/lessons.md)
2. Determine review scope from your request (diff, branch, specific files)
3. Run Pass 1: Bug/Logic review
4. Run Pass 2: Security review
5. Run Pass 3: Project conventions review
6. Score each finding (0-100 confidence), filter to >= 80
7. Deduplicate by file+line
8. Produce a formatted review report

Pass your review target: a file path, "my changes", "this branch", or "last commit".
