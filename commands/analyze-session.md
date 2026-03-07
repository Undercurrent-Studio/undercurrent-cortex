---
name: analyze-session
description: Run the conversation analyzer agent for a full adaptive immunity scan — detects corrections in today's journal, classifies patterns, writes lessons, and generates evolution proposals
---

Launch the `conversation-analyzer` agent to perform a full adaptive immunity scan of today's session.

The agent will:
1. Read today's journal for correction events (`[reasoning-miss]` tags, `[correction]` tags, and explicit user corrections)
2. Cross-reference with existing lessons in `tasks/lessons.md`
3. Write new or updated lessons
4. Generate evolution proposals when patterns recur 3+ times
5. Assess hook/skill health and propose repairs

No arguments needed. The agent reads the current date's journal automatically.
