#!/usr/bin/env bash
# Shared JSON string escaping — sourced by hook scripts that output JSON.
# Extracted from hooks/session-start (original lines 8-16).

escape_for_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}
