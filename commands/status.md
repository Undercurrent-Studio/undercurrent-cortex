---
name: status
description: Display the current organism statusline — session activity, health pulse, lessons absorbed, and pending mutations
---

# Status

Display the organism statusline showing current session activity and cross-session health.

## Steps

1. Run: `bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/statusline.sh"`
2. Display the two-line output directly — do not wrap in code blocks or add commentary
3. If the output is empty or the script fails, say: "Statusline unavailable — state files may not exist yet."

## What the lines mean

- **Line 1**: Session activity — edits since last commit, total commits, whether tests were run and docs updated
- **Line 2**: Organism health — heart color shows health pulse, lessons absorbed from tasks/lessons.md, pending evolution proposals, trend direction
- Heart colors: 💚 thriving, 💛 adapting, 🧡 cautious, ❤️‍🩹 stressed
