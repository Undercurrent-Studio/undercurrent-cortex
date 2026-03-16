#!/usr/bin/env bash
# bootstrap-hooks.sh — Inject PreToolUse/PostToolUse command hooks into settings.local.json
# WORKAROUND: Plugin hooks.json command hooks silently dropped for PreToolUse/PostToolUse
# See: https://github.com/anthropics/claude-code/issues/34573
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

# Use absolute path — ${CLAUDE_PLUGIN_ROOT} only resolves in plugin hooks.json,
# not in settings.local.json. We pass PLUGIN_ROOT from the shell environment.
plugin_root_ref = os.environ.get("PLUGIN_ROOT", "")

pre_hook = {
    "_cortex_bootstrap": True,
    "type": "command",
    "command": f'"C:/Program Files/Git/bin/bash.exe" "{plugin_root_ref}/hooks/scripts/pre-dispatch.sh"',
    "timeout": 30,
    "async": False
}

post_hook = {
    "_cortex_bootstrap": True,
    "type": "command",
    "command": f'"C:/Program Files/Git/bin/bash.exe" "{plugin_root_ref}/hooks/scripts/post-dispatch.sh"',
    "timeout": 30,
    "async": True
}

pre_matcher = "Write|Edit"
post_matcher = ".*"

# Read existing settings or start fresh
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
    """Check if any hook group already has a cortex bootstrap entry."""
    for group in hook_list:
        for h in group.get("hooks", []):
            if h.get("_cortex_bootstrap"):
                return True
    return False

# --- PreToolUse ---
if "PreToolUse" not in hooks:
    hooks["PreToolUse"] = []

if not has_cortex_bootstrap(hooks["PreToolUse"]):
    found = False
    for group in hooks["PreToolUse"]:
        if group.get("matcher") == pre_matcher:
            group["hooks"].append(pre_hook)
            found = True
            break
    if not found:
        hooks["PreToolUse"].append({
            "matcher": pre_matcher,
            "hooks": [pre_hook]
        })
    changed = True
    print("bootstrap-hooks: injected PreToolUse command hook", file=sys.stderr)
else:
    print("bootstrap-hooks: PreToolUse already bootstrapped, skipping", file=sys.stderr)

# --- PostToolUse ---
if "PostToolUse" not in hooks:
    hooks["PostToolUse"] = []

if not has_cortex_bootstrap(hooks["PostToolUse"]):
    found = False
    for group in hooks["PostToolUse"]:
        if group.get("matcher") == post_matcher:
            group["hooks"].append(post_hook)
            found = True
            break
    if not found:
        hooks["PostToolUse"].append({
            "matcher": post_matcher,
            "hooks": [post_hook]
        })
    changed = True
    print("bootstrap-hooks: injected PostToolUse command hook", file=sys.stderr)
else:
    print("bootstrap-hooks: PostToolUse already bootstrapped, skipping", file=sys.stderr)

# Write back only if changed
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
