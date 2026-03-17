#!/usr/bin/env bash
# bootstrap-hooks.sh - Inject PreToolUse/PostToolUse command hooks into settings.local.json
# WORKAROUND: Plugin hooks.json command hooks broken for PreToolUse/PostToolUse only
# See: https://github.com/anthropics/claude-code/issues/34573
# Other events (Stop, SessionEnd, PreCompact, UserPromptSubmit) work from hooks.json.
# Remove this entire file when the bug is fixed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source state-io for PROJECT_DIR
source "$SCRIPT_DIR/lib/state-io.sh" 2>/dev/null || true

# Fallback: derive PROJECT_DIR from git root
if [ -z "${PROJECT_DIR:-}" ]; then
  PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
fi

if [ -z "$PROJECT_DIR" ]; then
  echo "bootstrap-hooks: no PROJECT_DIR, skipping" >&2
  exit 0
fi

if [ -z "${PLUGIN_ROOT:-}" ]; then
  echo "bootstrap-hooks: no PLUGIN_ROOT, skipping" >&2
  exit 0
fi

SETTINGS_FILE="${PROJECT_DIR}/.claude/settings.local.json"

# Use python3 for reliable JSON manipulation
python3 - "$SETTINGS_FILE" <<'PYEOF'
import json
import sys
import os

settings_path = sys.argv[1]
plugin_root_ref = os.environ.get("PLUGIN_ROOT", "").replace("\\", "/")

# Only PreToolUse and PostToolUse need bootstrap (hooks.json bug #34573)
# Other events (Stop, SessionEnd, PreCompact, UserPromptSubmit) work from hooks.json
HOOKS_TO_INJECT = [
    {
        "event": "PreToolUse",
        "matcher": "Write|Edit",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/pre-dispatch.sh"',
            "timeout": 30,
            "async": False
        }
    },
    {
        "event": "PostToolUse",
        "matcher": ".*",
        "hook": {
            "_cortex_bootstrap": True,
            "type": "command",
            "command": f'bash "{plugin_root_ref}/hooks/scripts/post-dispatch.sh"',
            "timeout": 30,
            "async": True
        }
    },
]

settings = {}
if os.path.isfile(settings_path):
    try:
        with open(settings_path, 'r', encoding='utf-8') as f:
            settings = json.load(f)
    except (json.JSONDecodeError, IOError):
        print("bootstrap-hooks: settings.local.json unreadable, creating fresh", file=sys.stderr)
        settings = {}

if "hooks" not in settings:
    settings["hooks"] = {}

hooks = settings["hooks"]
changed = False

def has_cortex_bootstrap(hook_list):
    for group in hook_list:
        for h in group.get("hooks", []):
            if h.get("_cortex_bootstrap"):
                return True
    return False

# Clean up: remove bootstrap entries for events that work from hooks.json
for event in ["UserPromptSubmit", "PreCompact", "Stop", "SessionEnd"]:
    if event in hooks:
        for group in hooks[event]:
            original_len = len(group.get("hooks", []))
            group["hooks"] = [h for h in group.get("hooks", []) if not h.get("_cortex_bootstrap")]
            if len(group.get("hooks", [])) < original_len:
                changed = True
                print(f"bootstrap-hooks: removed stale {event} bootstrap (works from hooks.json)", file=sys.stderr)
        hooks[event] = [g for g in hooks[event] if g.get("hooks")]
        if not hooks[event]:
            del hooks[event]

for entry in HOOKS_TO_INJECT:
    event = entry["event"]
    matcher = entry["matcher"]
    hook = entry["hook"]

    if event not in hooks:
        hooks[event] = []

    if not has_cortex_bootstrap(hooks[event]):
        found = False
        for group in hooks[event]:
            if group.get("matcher") == matcher:
                group["hooks"].append(hook)
                found = True
                break
        if not found:
            hooks[event].append({
                "matcher": matcher,
                "hooks": [hook]
            })
        changed = True
        print(f"bootstrap-hooks: injected {event} command hook", file=sys.stderr)
    else:
        print(f"bootstrap-hooks: {event} already bootstrapped, skipping", file=sys.stderr)

if changed:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    with open(settings_path, 'w', encoding='utf-8') as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print("bootstrap-hooks: wrote updated settings.local.json", file=sys.stderr)
else:
    print("bootstrap-hooks: no changes needed", file=sys.stderr)
PYEOF

exit 0
